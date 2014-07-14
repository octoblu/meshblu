'use strict';
var mosca = require('mosca');
var _ = require('lodash');

var config = require('./config');
var redis = require('./lib/redis');
var whoAmI = require('./lib/whoAmI');
var logData = require('./lib/logData');
var updateSocketId = require('./lib/updateSocketId');
var sendMessageCreator = require('./lib/sendMessage');
var wrapMqttMessage = require('./lib/wrapMqttMessage');
var securityImpl = require('./lib/getSecurityImpl');
var updateFromClient = require('./lib/updateFromClient');

var server;
var io;
if(config.redis){
  io = require('socket.io-emitter')(redis.client);
}

config.mqtt = config.mqtt || {};
var dataStore;
if(config.mqtt.databaseUrl){
  dataStore = {
    type: 'mongo',
    url: config.mqtt.databaseUrl,
    pubsubCollection: 'mqtt',
    mongo: {}
  };
}


var dataLogger = {
    level: 'debug'
};

var settings = {
  port: config.mqtt.port || 1883,
  backend: dataStore || {},
  logger: dataLogger
};

var skynetTopics = ['message',
                    'messageAck',
                    'update',
                    'data',
                    'gatewayConfig',
                    'whoami',
                    'tb',
                    'directText'];

function endsWith(str, suffix) {
  return str.indexOf(suffix, str.length - suffix.length) !== -1;
}

process.on("uncaughtException", function(error) {
  return console.log(error.stack);
});


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
    //console.log('done!');
  });

}

function emitToClient(topic, device, msg){
  console.log('emtting to client', topic, device, msg);
  if(device.protocol === "mqtt"){
    // MQTT handler
    console.log('sending mqtt', device);
    mqttEmitter(device.uuid, wrapMqttMessage(topic, msg), {qos: msg.qos || 0});
  }
  else{
    socketEmitter(device.uuid, topic, msg);
  }

}

var sendMessage = sendMessageCreator(socketEmitter, mqttEmitter);

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

function sendActivity(data){
  //TODO throttle, maybe only send out with IP
  if(config.broadcastActivity){
    console.log("SENDING ACTIVITY DATA");
    data = data || {};
    var activityMessage = {};
    activityMessage.devices = "*";
    activityMessage.payload = data;
    sendMessage({uuid: config.uuid}, activityMessage);
  }

}

// Accepts the connection if the username and password are valid
function authenticate(client, username, password, callback) {
  console.log('\nauthenticate username:', username.toString(),'password', password.toString(),'client.id:', client.id, client.clientId, client.client_id);

  if(username && username.toString() === 'skynet'){
    if(password && password.toString() === config.mqtt.skynetPass){
      client.skynetDevice = {
        uuid: 'skynet',
      };
      callback(null, true);
    }else{
      callback('unauthorized');
    }
  }else{
    var data = {
      uuid: username.toString(),
      token: password.toString(),
      socketid: username.toString(),
      protocol: 'mqtt',
      online: 'true'
    };

    console.log('attempting authenticate', data);


    updateSocketId(data, function(auth){
      if (auth.device){
          client.skynetDevice = auth.device;
          console.log('authenticated: ' + auth.device.uuid);
          callback(null, true);

      } else {
        callback('unauthorized');
      }

    });
  }


}

// In this case the client authorized as alice can publish to /users/alice taking
// the username from the topic and verifing it is the same of the authorized user
function authorizePublish(client, topic, payload, callback) {

  //console.log('authorizePublish', topic, 'typeof:', typeof payload, 'payload:', payload, payload.toString());

  function reject(reason){
    callback('unauthorized');
    console.log('\nunauthorized Publish', typeof topic, '-'+topic+'-', client.id, payload, reason);
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
          //console.log('pre publish', payloadObj);
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
    console.log('\n subscribed', topic);
    callback(null, true);
    //console.log('authorized subscribe', topic, client.skynetDevice);
  }else{
    callback('unauthorized');
  }

}

// fired when the mqtt server is ready
function setup() {
  console.log('Skynet MQTT server started on port', config.mqtt.port);
  server.authenticate = authenticate;
  server.authorizePublish = authorizePublish;
  server.authorizeSubscribe = authorizeSubscribe;
}

// // fired when a message is published

server = new mosca.Server(settings);
server.on('ready', setup);

server.on('published', function(packet, client) {
  console.log('\nPublished payload:', packet.payload, ' topic:', packet.topic);
  try{
    var msg, ack;
    if('message' === packet.topic){
      sendMessage(client.skynetDevice, JSON.parse(packet.payload.toString()));
    }
    else if('tb' === packet.topic){
      sendMessage(client.skynetDevice, packet.payload.toString(), 'tb');
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
        });
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
        console.log('data log', results);

        // Send messsage regarding data update
        var message = {};
        message.payload = msg;
        // message.devices = data.uuid;
        message.devices = "*";

        console.log('message: ' + JSON.stringify(message));

        sendMessage(client.skynetDevice, message);

      });
    }

    //var payload = JSON.parse(packet.payload.toString());
    //console.log('payload', payload);
  }catch(ex){
    console.log('error publishing');
  }

});

// fired when a client connects or disconnects
server.on('clientConnected', function(client) {
  console.log('Client Connected:', client.id, client.skynetDevice);
  //console.log('Client Connected:', client.connection.stream);
});

server.on('clientDisconnected', function(client) {
  console.log('Client Disconnected:', client.id);
});
