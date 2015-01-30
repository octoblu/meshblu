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

var mqttServer = function(config, parentConnection){
  var server, io;

  if(config.redis && config.redis.host){
    var redis = require('./redis');
    io = require('socket.io-emitter')(redis.client);
  }

  var dataLogger = {
      level: 'debug'
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

  var skynetTopics = ['message',
                      'messageAck',
                      'update',
                      'data',
                      'config',
                      'gatewayConfig',
                      'whoami',
                      'tb',
                      'directText',
                      'resetToken',
                      'getPublicKey'];

  function endsWith(str, suffix) {
    return str.indexOf(suffix, str.length - suffix.length) !== -1;
  }


  function socketEmitter(uuid, topic, data){
    if(io){
      io.in(uuid).emit(topic, data);
    }
  }

  function mqttEmitter(uuid, wrappedData, options){
    options = options || {};
    var message = {
      topic: uuid,
      payload: wrappedData, // or a Buffer
      qos: options.qos || 0, // 0, 1, or 2
      retain: false // or true
    };

    server.publish(message, function() {
    });

  }

  function emitToClient(topic, device, msg){
    if(device.protocol === "mqtt"){
      // MQTT handler
      mqttEmitter(device.uuid, wrapMqttMessage(topic, msg), {qos: msg.qos || 0});
    }
    else{
      socketEmitter(device.uuid, topic, msg);
    }

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
    if(fromDevice && data && data.ack){
      whoAmI(data.devices, false, function(check){
        if(!check.error && securityImpl.canSend(fromDevice, check)){
          emitToClient('messageAck', check, data);
        }
      });
    }
  }

  function serverAck(fromDevice, ack, resp){
    if(fromDevice && ack && resp){
      var msg = {
        ack: ack,
        payload: resp,
        qos: resp.qos
      };
      mqttEmitter(fromDevice.uuid, wrapMqttMessage('messageAck', msg), {qos: msg.qos || 0});
    }
  }


  // Accepts the connection if the username and password are valid
  function authenticate(client, username, password, callback) {
    if(username && username.toString() === 'skynet' && password){
      if(password && password.toString() === config.mqtt.skynetPass){
        client.skynetDevice = {
          uuid: 'skynet',
        };
        callback(null, true);
      }else{
        callback('unauthorized');
      }
    }else if(username && password){
      var data = {
        uuid: username.toString(),
        token: password.toString(),
        socketid: username.toString(),
        ipAddress: client.connection.stream.remoteAddress,
        protocol: 'mqtt',
        online: true
      };

      updateSocketId(data, function(auth){
        if (auth.device){
            client.skynetDevice = auth.device;
            callback(null, true);
        } else {
          callback('unauthorized');
        }
      });
    }else{
      callback('unauthorized');
    }
  }

  // In this case the client authorized as alice can publish to /users/alice taking
  // the username from the topic and verifing it is the same of the authorized user
  function authorizePublish(client, topic, payload, callback) {

    function reject(reason){
      callback('unauthorized');
    }

    //TODO refactor this mess
    if(client.skynetDevice){
      if(client.skynetDevice.uuid === 'skynet'){
        callback(null, true);
      }else if(_.contains(skynetTopics, topic)){
        try{
          var payloadObj = payload.toString();
          try{
            payloadObj = JSON.parse(payload.toString());
            payloadObj.fromUuid = client.skynetDevice.uuid;
            callback(null, new Buffer(JSON.stringify(payloadObj)));
          }catch(exp){
            callback(null, true);
          }

        }catch(err){
          reject(err);
        }
      }else{
        reject('invalid topic');
      }
    }else{
      reject('no skynet device');
    }
  }

  // In this case the client authorized as alice can subscribe to /users/alice taking
  // the username from the topic and verifing it is the same of the authorized user
  function authorizeSubscribe(client, topic, callback) {

    if(endsWith(topic, '_bc') || endsWith(topic, '_tb') ||
      (client.skynetDevice &&
        ((client.skynetDevice.uuid === 'skynet') || (client.skynetDevice.uuid === topic)))){
      callback(null, true);
    }else{
      callback('unauthorized');
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

  _.each(server.servers, function(s){
    s.on('error', console.error);
  })

  server.on('published', function(packet, client) {
    try{
      var msg, ack;
      if('message' === packet.topic){
        sendMessage(client.skynetDevice, JSON.parse(packet.payload.toString()));
      }
      else if('tb' === packet.topic){
        sendMessage(client.skynetDevice, {payload: packet.payload.toString(), devices: ['*']}, 'tb');
      }
      else if('directText' === packet.topic){
        sendMessage(client.skynetDevice, JSON.parse(packet.payload.toString()), 'tb');
      }
      else if('messageAck' === packet.topic){
        clientAck(client.skynetDevice, JSON.parse(packet.payload.toString()));
      }
      else if('update' === packet.topic){
        msg = JSON.parse(packet.payload.toString());
        if(msg.ack){
          ack = msg.ack;
          delete msg.ack;
          updateFromClient(client.skynetDevice, msg, function(resp){
            serverAck(client.skynetDevice, ack, resp);
            whoAmI(client.skynetDevice.uuid, true, function(data){
              emitToClient('config', client.skynetDevice, data);
            })
          });
        }
      }
      else if('resetToken' === packet.topic){
        msg = JSON.parse(packet.payload.toString());
        if(msg.ack){
          ack = msg.ack;
          delete msg.ack;
          resetToken(client.skynetDevice, msg, function(err,token){
            serverAck(client.skynetDevice, ack, token);
            var message = {uuid: msg.uuid, token: token}
            emitToClient('token', client.skynetDevice, message);
          });
        }
      }
      else if('getPublicKey' === packet.topic) {
        msg = JSON.parse(packet.payload.toString());
        if(msg.ack) {
          ack = msg.ack;
          delete msg.ack;
          getPublicKey(msg.uuid, function(error, publicKey){
            serverAck(client.skynetDevice, ack, publicKey);
            var message = {uuid: msg.uuid, publicKey: publicKey};
            emitToClient('publicKey', client.skynetDevice, JSON.stringify(message));
          })
        }
      }
      else if('whoami' === packet.topic){
        msg = JSON.parse(packet.payload.toString());
        if(msg.ack){
          ack = msg.ack;
          delete msg.ack;
          whoAmI(client.skynetDevice.uuid, true, function(resp){
            serverAck(client.skynetDevice, ack, resp);
          });
        }
      }
      else if('data' === packet.topic){
        msg = JSON.parse(packet.payload.toString());
        delete msg.token;
        msg.uuid = client.skynetDevice.uuid;

        logData(msg, function(results){
          // Send messsage regarding data update
          var message = {};
          message.payload = msg;
          // message.devices = data.uuid;
          message.devices = "*";

          sendMessage(client.skynetDevice, message);
        });
      }
    }catch(ex){
      console.error(ex);
    }
  });
};

module.exports = mqttServer;
