'use strict';
var _ = require('lodash');
var mosca = require('mosca');
var whoAmI = require('./whoAmI');
var logData = require('./logData');
var resetToken = require('./resetToken');
var getPublicKey = require('./getPublicKey');
var securityImpl = require('./getSecurityImpl');
var proxyListener = require('./proxyListener');
var updateSocketId = require('./updateSocketId');
var MessageIOClient = require('./messageIOClient');
var wrapMqttMessage = require('./wrapMqttMessage');
var updateFromClient = require('./updateFromClient');
var sendMessageCreator = require('./sendMessage');
var MeshbluEventEmitter = require('./MeshbluEventEmitter');
var saveDataIfAuthorized = require('./saveDataIfAuthorized');
var generateAndStoreToken = require('./generateAndStoreToken');
var createMessageIOEmitter = require('./createMessageIOEmitter');
var debug = require('debug')('meshblu:mqtt');

var mqttServer = function(config, parentConnection){
  var server;

  var dataLogger = {
      level: 'warn'
  };

  var settings = {
    port: config.mqtt.port || 1883,
    logger: dataLogger,
    stats: config.mqtt.stats || false
  };

  config.mqtt = config.mqtt || {};

  if(config.redis && config.redis.host){
    var ascoltatore = {
      type: 'redis',
      redis: require('redis'),
      port: config.redis.port || 6379,
      return_buffers: true, // to handle binary payloads
      host: config.redis.host || "localhost"
    };
    settings.backend = ascoltatore;
    settings.persistence= {
      factory: mosca.persistence.Redis,
      host: ascoltatore.host,
      port: ascoltatore.port
    };

  }else if(config.mqtt.databaseUrl){
    settings.backend = {
      type: 'mongo',
      url: config.mqtt.databaseUrl,
      pubsubCollection: 'mqtt',
      mongo: {}
    };
  }else{
    settings.backend = {};
  }

  var skynetTopics = [
    'message',
    'update',
    'config',
    'whoami',
    'resetToken',
    'getPublicKey',
    'generateAndStoreToken',
    'messageAck',
    'tb',
  ];

  function endsWith(str, suffix) {
    return str.indexOf(suffix, str.length - suffix.length) !== -1;
  }

  var socketEmitter = createMessageIOEmitter();

  function mqttEmitter(uuid, wrappedData, options){
    options = options || {};
    var message = {
      topic: uuid,
      payload: wrappedData, // or a Buffer
      qos: options.qos || 0, // 0, 1, or 2
      retain: false // or true
    };
    debug('publish (mqttEmitter)', message);
    server.publish(message, _.noop);
  }

  // Use this for sending messages to client
  function emitToClientDirectly(uuid, message, options){
    options = _.defaults(options, {qos: 0});
    mqttEmitter(uuid, wrapMqttMessage(message), options);
  }

  // This is just for configActivity
  function emitToClient(topic, device, msg){
    emitToClientDirectly(device.uuid, {topic: topic, payload: msg});
  }

  var sendMessage = sendMessageCreator(socketEmitter, mqttEmitter, parentConnection);
  var meshbluEventEmitter = new MeshbluEventEmitter(config.uuid, config.forwardEventUuids, sendMessage);
  if(parentConnection){
    parentConnection.on('message', function(data, fn){
      if(data){
        var devices = data.devices;
        if (!_.isArray(devices)) {
          devices = [devices];
        }
        _.each(devices, function(device) {
          if(device !== config.parentConnection.uuid){
            sendMessage({uuid: data.fromUuid}, data, fn);
          }
        });
      }
    });
  }

  // Accepts the connection if the username and password are valid
  function authenticate(client, username, password, callback) {
    if(!username || !password){
      return callback('unauthorized');
    }
    username = username.toString();
    password = password.toString();
    debug('MQTT auth', username);
    if(username === 'skynet' && password && password === config.mqtt.skynetPass){
      client.skynetDevice = {
        uuid: 'skynet',
      };
      return callback(null, true);
    }
    var data = {
      uuid: username,
      token: password,
      ipAddress: client.connection.stream.remoteAddress,
      protocol: 'mqtt',
      online: true
    };

    updateSocketId(data, function(auth){
      if(!auth.device){
        return callback('unauthorized');
      }
      client.skynetDevice = auth.device;

      debug('connecting for client', client.id);
      client.messageIOClient = new MessageIOClient();

      client.messageIOClient.on('message', function(message){
        debug(client.id, 'relay mqtt message', message);
        emitToClientDirectly(client.skynetDevice.uuid, {topic: 'message', payload: message}, {qos: message.qos || 0});
      });

      client.messageIOClient.on('data', function(message){
        debug(client.id, 'relay mqtt data', message);
        emitToClientDirectly(client.skynetDevice.uuid, {topic: 'data', payload: message}, {qos: message.qos || 0});
      });

      client.messageIOClient.on('config', function(message){
        debug(client.id, 'relay mqtt config', message);
        emitToClientDirectly(client.skynetDevice.uuid, {topic: 'config', payload: message}, {qos: message.qos || 0});
      });

      debug(client.id, 'subscribing to received', client.skynetDevice.uuid);
      client.messageIOClient.subscribe(client.skynetDevice.uuid, ['received', 'config', 'data']);
      callback(null, true);
    });
  }

  // In this case the client authorized as alice can publish to /users/alice taking
  // the username from the topic and verifing it is the same of the authorized user
  function authorizePublish(client, topic, payload, callback) {
    function reject(reason){
      callback(reason || 'unauthorized');
    }
    if(!client.skynetDevice){
      return reject();
    }
    if(client.skynetDevice.uuid === 'skynet'){
      callback(null, true);
    }else if(_.contains(skynetTopics, topic)){
      var payload = payload.toString();
      try{
        var payloadObj = JSON.parse(payload);
        payloadObj.fromUuid = client.skynetDevice.uuid;
        callback(null, new Buffer(JSON.stringify(payloadObj)));
      }catch(exp){
        callback('invalid payload');
      }
    }else{
      reject('invalid topic');
    }
  }

  // In this case the client authorized as alice can subscribe to /users/alice taking
  // the username from the topic and verifing it is the same of the authorized user
  function authorizeSubscribe(client, topic, callback) {
    if(!client.skynetDevice){
      return callback('unauthorized');
    }
    if(endsWith(topic, '_bc') || endsWith(topic, '_tb')){
      return callback(null, true);
    }
    if(client.skynetDevice.uuid === 'skynet' || client.skynetDevice.uuid === topic){
      return callback(null, true);
    }
  }

  // fired when the mqtt server is ready
  function setup() {
    if (config.useProxyProtocol) {
      _.each(server.servers, function(server){
        proxyListener.resetListeners(server);
      })
    }

    server.authenticate = authenticate;
    server.authorizePublish = authorizePublish;
    server.authorizeSubscribe = authorizeSubscribe;
    console.log('MQTT listening at mqtt://0.0.0.0:' + settings.port);
  }

  // // fired when a message is published
  server = new mosca.Server(settings);

  server.on('ready', setup);

  _.each(server.servers, function(singleServer){
    singleServer.on('error', function(error){
      debug('error event for mqtt server', error);
    });
  })

  server.on('clientConnected', function(client) {
    debug('client connected:', client.id);
  });

  server.on('clientDisconnected', function(client) {
    debug('client disconnected:', client.id);
    if (client.messageIOClient) {
      client.messageIOClient.close();
    }
  });

  function parsePacket(packet){
    var topic, payload, parsedPayload;
    topic = packet.topic;
    payload = packet.payload || '';
    if(payload instanceof Buffer){
      payload = payload.toString();
    }

    try{
      parsedPayload = JSON.parse(payload);
    }catch(parseError){}

    if(parsedPayload && _.isPlainObject(parsedPayload)){
      payload = parsedPayload;
    }

    return {
      payload: payload,
      topic: topic
    }
  }

  server.on('subscribed', function(topic, client){
    debug('client subscribed', topic, client.id);
    client.messageIOClient.subscribe(client.skynetDevice.uuid, ['received']);
  });

  server.on('published', function(packet, client) {
    var msg, ack, payload, packetObj, sanitizedRequest, topic, request;
    packetObj = parsePacket(packet);
    payload = packetObj.payload;
    topic = packetObj.topic;
    if(!topic || !_.contains(skynetTopics, topic)){
      return;
    }

    debug('on published', 'topic:', topic, 'payload:', payload);
    msg = _.cloneDeep(payload);
    request = _.cloneDeep(payload);
    sanitizedRequest = _.omit(_.cloneDeep(payload), 'fromUuid', 'callbackId');

    if('message' === topic || 'tb' === topic){
      debug('sendMessage', msg);
      sendMessage(client.skynetDevice, msg);
      meshbluEventEmitter.log('message', null, {request: sanitizedRequest, fromUuid: client.skynetDevice.uuid});
    }
    else if('update' === topic){
      updateFromClient(client.skynetDevice, msg, function(data){
        debug('updateFromClient', arguments);
        var logRequest = {params: {$set: sanitizedRequest}, query: {uuid: sanitizedRequest.uuid}};
        var errorMessage = data.error && data.error.message;
        meshbluEventEmitter.log('update', data.error, {request: logRequest, fromUuid: client.skynetDevice.uuid, error: errorMessage});

        var message = {topic: 'update', payload: {}, _request: request};
        if(errorMessage){
          message.topic = 'error';
          message.payload.message = errorMessage;
        }
        emitToClientDirectly(client.skynetDevice.uuid, message);
      });
    }
    else if('resetToken' === topic){
      resetToken(client.skynetDevice, msg.uuid, emitToClient, function(error, token){
        var errorMessage = error || undefined;

        meshbluEventEmitter.log('resettoken', error, {request: {uuid: msg.uuid}, fromUuid: client.skynetDevice.uuid, error: errorMessage});
        if(error != null){
          return emitToClientDirectly(client.skynetDevice.uuid, {topic: 'error', payload: {message: error}, _request: request});
        }
        var message = {topic: 'token', payload: {uuid: msg.uuid, token: token}, _request: request};
        emitToClientDirectly(client.skynetDevice.uuid, message);
      });
    }
    else if('generateAndStoreToken' === topic){
      generateAndStoreToken(client.skynetDevice, msg, function(error, result){
        var errorMessage = error && error.message || undefined;
        meshbluEventEmitter.log('generatetoken', error, {request: {uuid: msg.uuid}, fromUuid: client.skynetDevice.uuid, error: errorMessage});
        if(error != null){
          return emitToClientDirectly(client.skynetDevice.uuid, {topic: 'error', payload: error, _request: request});
        }
        var message = {topic: 'generateAndStoreToken', payload: {uuid: msg.uuid, token: result.token, tag: msg.tag}, _request: request};
        emitToClientDirectly(client.skynetDevice.uuid, message);
      });
    }
    else if('getPublicKey' === topic) {
      getPublicKey(msg.uuid, function(error, publicKey){
        var errorMessage = error && error.message || undefined;
        meshbluEventEmitter.log('getpublickey', error, {request: sanitizedRequest, error: errorMessage});
        if(error != null){
          return emitToClientDirectly(client.skynetDevice.uuid, {topic: 'error', payload: error, _request: request});
        }
        var message = {topic: 'publicKey', payload: {publicKey: publicKey}, _request: request};
        emitToClientDirectly(client.skynetDevice.uuid, message);
      })
    }
    else if('whoami' === topic){
      whoAmI(client.skynetDevice.uuid, true, function(resp){
        meshbluEventEmitter.log('whoami', null, {request: sanitizedRequest, fromUuid: client.skynetDevice.uuid});
        emitToClientDirectly(client.skynetDevice.uuid, {topic: 'whoami', payload: resp, _request: request});
      });
    }
  });
};

module.exports = mqttServer;
