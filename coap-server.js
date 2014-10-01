'use strict';
var _ = require('lodash');
var coap       = require('coap');
var config = require('./config');
var redis = require('./lib/redis');
var throttles = require('./lib/getThrottles');
var sendMessageCreator = require('./lib/sendMessage');
var setupMqttClient = require('./lib/setupMqttClient');
var setupCoapRoutes = require('./lib/setupCoapRoutes');
var setupGatewayConfig = require('./lib/setupGatewayConfig');
var sendActivity = require('./lib/sendActivity');
var createSocketEmitter = require('./lib/createSocketEmitter');
var wrapMqttMessage = require('./lib/wrapMqttMessage');
var parentConnection = require('./lib/getParentConnection');

var io;
if(config.redis && config.redis.host){
  var store = redis.createIoStore();
  store.subClient.psubscribe('socket.io#*', function(err){
    if (err){
      console.log('error setting up socket.io subcription', err);
    }
  });

  io = require('socket.io-emitter')(redis.client);
}

var socketEmitter = createSocketEmitter(io, null);

function mqttEmitter(uuid, wrappedData, options){
  if(mqttclient){
    mqttclient.publish(uuid, wrappedData, options);
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

var coapRouter = require('./lib/coapRouter'),
    coapServer = coap.createServer(),
    coapConfig = config.coap || {};


function emitToClient(topic, device, msg){
  if(device.protocol === "mqtt"){
    // MQTT handler
    mqttEmitter(device.uuid, wrapMqttMessage(topic, msg), {qos:msg.qos || 0});
  }
  else{
    socketEmitter(device.uuid, topic, msg);
  }
}

var skynet = {
  sendMessage: sendMessage,
  gateway : setupGatewayConfig(emitToClient),
  sendActivity: sendActivity,
  throttles: throttles,
  io: io,
  emitToClient: emitToClient
};

var mqttclient = setupMqttClient(skynet, config);

process.on("uncaughtException", function(error) {
  return console.log(error.message, error.stack);
});

setupCoapRoutes(coapRouter, skynet);

coapServer.on('request', coapRouter.process);

var coapPort = coapConfig.port || 5683;
var coapHost = coapConfig.host || 'localhost';

coapServer.listen(coapPort, function () {
  console.log('CoAP listening at coap://' + coapHost + ':' + coapPort);
});
