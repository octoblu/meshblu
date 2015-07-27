'use strict';
var _ = require('lodash');
var mosca = require('mosca');
var whoAmI = require('./whoAmI');
var logData = require('./logData');
var resetToken = require('./resetToken');
var updateSocketId = require('./updateSocketId');
var sendMessageCreator = require('./sendMessage');
var wrapMqttMessage = require('./wrapMqttMessage');
var getPublicKey = require('./getPublicKey');
var securityImpl = require('./getSecurityImpl');
var updateFromClient = require('./updateFromClient');
var proxyListener = require('./proxyListener');
var generateAndStoreToken = require('./generateAndStoreToken');
var debug = require('debug')('meshblu:mqtt');
var createMessageIOEmitter = require('./createMessageIOEmitter');
var MessageIOClient = require('./messageIOClient');
var saveDataIfAuthorized = require('./saveDataIfAuthorized');

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
    'data',
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
    debug('publish', message);
    server.publish(message, _.noop);
  }

  function emitToClient(topic, device, msg){
    socketEmitter(device.uuid, topic, msg);
  }

  var sendMessage = sendMessageCreator(socketEmitter, mqttEmitter, parentConnection);
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

  function clientAck(fromDevice, data){
    if(!formDevice || (!data && !data.ack)){
      return emitToClient('error', fromDevice, { error : "invalid client"});
    }
    whoAmI(data.devices, false, function(check){
      if(check.error){
        return emitToClient('error', fromDevice, { error : "unauthorized"});
      }
      securityImpl.canSend(fromDevice, check, function(error, permission){
         if(error || ! permission){
           return emitToClient('error', check, { error : "unauthorized"});
         }
         emitToClient('messageAck', check, data);
      });
    });
  }

  function serverAck(fromDevice, ack, resp){
    if(!(fromDevice && ack && resp)){
      return;
    }
    var msg = {
      ack: ack,
      payload: resp,
      qos: resp.qos
    };
    mqttEmitter(fromDevice.uuid, wrapMqttMessage('messageAck', msg), {qos: msg.qos || 0});
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
      socketid: username,
      ipAddress: client.connection.stream.remoteAddress,
      protocol: 'mqtt',
      online: true
    };

    updateSocketId(data, function(auth){
      if(!auth.device){
        return callback('unauthorized');
      }
      client.skynetDevice = auth.device;

      debug('connecting for client', client.skynetDevice.uuid);
      client.messageIOClient = new MessageIOClient();
      client.messageIOClient.on('message', function(message){
        debug(client.skynetDevice.uuid, 'relay mqtt message', message);
        mqttEmitter(client.skynetDevice.uuid, wrapMqttMessage(message.topic, message.payload), {qos: message.qos || 0});
      });

      client.messageIOClient.start()

      client.messageIOClient.subscribe(client.skynetDevice.uuid, ['received']);
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
  });

  server.on('published', function(packet, client) {
    var msg, ack, payload, topic;
    payload = packet.payload || '';
    payload = payload.toString();
    topic = packet.topic;
    if(!topic || !_.contains(skynetTopics, topic)){
      return debug('invalid topic (most likely not a problem)', topic);
    }
    debug('published', 'topic:', topic, 'payload:', payload);
    try{
      payload = JSON.parse(payload);
    }catch(parseError){
      debug('failed to parse payload', payload);
      return;
    }
    msg = _.cloneDeep(payload);
    ack = msg.ack;
    delete msg.ack;
    if('message' === topic || 'tb' === topic){
      debug('sendMessage', payload);
      sendMessage(client.skynetDevice, payload);
    }
    else if('messageAck' === topic){
      clientAck(client.skynetDevice, payload);
    }
    else if('update' === topic){
      updateFromClient(client.skynetDevice, msg, function(response){
        serverAck(client.skynetDevice, ack, response);
        whoAmI(client.skynetDevice.uuid, true, function(data){
          emitToClient('config', client.skynetDevice, data);
        })
      });
    }
    else if('resetToken' === topic){
      resetToken(client.skynetDevice, msg, emitToClient, function(err,token){
        serverAck(client.skynetDevice, ack, token);
        var message = {uuid: msg.uuid, token: token}
        emitToClient('token', client.skynetDevice, message);
      });
    }
    else if('generateAndStoreToken' === topic){
      generateAndStoreToken(client.skynetDevice, msg, function(err, result){
        serverAck(client.skynetDevice, ack, result);
        var message = {uuid: msg.uuid, token: result.token}
        emitToClient('generateAndStoreToken', client.skynetDevice, message);
      });
    }
    else if('getPublicKey' === topic) {
      getPublicKey(msg.uuid, function(error, publicKey){
        serverAck(client.skynetDevice, ack, publicKey);
        var message = {uuid: msg.uuid, publicKey: publicKey};
        emitToClient('publicKey', client.skynetDevice, JSON.stringify(message));
      })
    }
    else if('whoami' === topic){
      whoAmI(client.skynetDevice.uuid, true, function(resp){
        emitToClient('whoami', client.skynetDevice, JSON.stringify(resp));
      });
    }
    else if('data' === topic){
      delete msg.token;
      msg.uuid = msg.uuid || client.skynetDevice.uuid;
      saveDataIfAuthorized(sendMessage, client.skynetDevice, msg.uuid, msg, function(error, saved) {
        emitToClient('data', client.skynetDevice, JSON.stringify(msg));
      });
    }
  });
};

module.exports = mqttServer;
