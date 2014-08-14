'use strict';
var coap       = require('coap');
var config = require('./config');
var redis = require('./lib/redis');
var tokenthrottle = require("tokenthrottle");
var sendMessageCreator = require('./lib/sendMessage');

var setupCoapRoutes = require('./lib/setupCoapRoutes');
var whoAmI = require('./lib/whoAmI');
var logData = require('./lib/logData');
var updateSocketId = require('./lib/updateSocketId');
var securityImpl = require('./lib/getSecurityImpl');
var setupGatewayConfig = require('./lib/setupGatewayConfig');
var sendActivity = require('./lib/sendActivity');
var createSocketEmitter = require('./lib/createSocketEmitter');

var server;
var io;
if(config.redis && config.redis.host){
  io = require('socket.io-emitter')(redis.client);
}

var socketEmitter = createSocketEmitter(io, null);

function mqttEmitter(uuid, wrappedData, options){
  if(mqttclient){
    mqttclient.publish(uuid, wrappedData, options);
  }
}

var sendMessage = sendMessageCreator(socketEmitter, mqttEmitter);


var coapRouter = require('./lib/coapRouter'),
    coapServer = coap.createServer(),
    coapConfig = config.coap || {};


config.rateLimits = config.rateLimits || {};
// rate per second
var throttles = {
  connection : tokenthrottle({rate: config.rateLimits.connection || 3}),
  message : tokenthrottle({rate: config.rateLimits.message || 10}),
  data : tokenthrottle({rate: config.rateLimits.data || 10}),
  query : tokenthrottle({rate: config.rateLimits.query || 2}),
  whoami : tokenthrottle({rate: config.rateLimits.whoami || 10}),
  unthrottledIps : config.rateLimits.unthrottledIps || []
};

function emitToClient(topic, device, msg){
  if(device.protocol === "mqtt"){
    // MQTT handler
    console.log('sending mqtt', device);
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

process.on("uncaughtException", function(error) {
  return console.log(error.stack);
});

setupCoapRoutes(coapRouter, skynet);

coapServer.on('request', coapRouter.process);

var coapPort = coapConfig.port || 5683;
var coapHost = coapConfig.host || 'localhost';

coapServer.listen(coapPort, function () {
  console.log('CoAP listening at coap://' + coapHost + ':' + coapPort);
});
