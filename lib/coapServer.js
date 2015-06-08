'use strict';
var _ = require('lodash');
var coap       = require('coap');
var throttles = require('./getThrottles');
var sendMessageCreator = require('./sendMessage');
var setupMqttClient = require('./setupMqttClient');
var setupCoapRoutes = require('./setupCoapRoutes');
var sendActivity = require('./sendActivity');
var sendConfigActivity = require('./sendConfigActivity');
var createMessageIOEmitter = require('./createMessageIOEmitter');
var wrapMqttMessage = require('./wrapMqttMessage');

var coapServer = function(config, parentConnection){
  var socketEmitter = createMessageIOEmitter();

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

  var coapRouter = require('./coapRouter'),
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
    sendActivity: sendActivity,
    sendConfigActivity: sendConfigActivity,
    throttles: throttles,
    io: io,
    emitToClient: emitToClient
  };

  var mqttclient = setupMqttClient(skynet, config);

  setupCoapRoutes(coapRouter, skynet);

  coapServer.on('request', coapRouter.process);
  coapServer.on('error', console.error);

  var coapPort = coapConfig.port || 5683;
  var coapHost = coapConfig.host || 'localhost';

  coapServer.listen(coapPort, function () {
    console.log('CoAP listening at coap://' + coapHost + ':' + coapPort);
  });
}

module.exports = coapServer;
