'use strict';
var _ = require('lodash');
var coap       = require('coap');
var throttles = require('./getThrottles');
var sendMessageCreator = require('./sendMessage');
var setupCoapRoutes = require('./setupCoapRoutes');
var sendActivity = require('./sendActivity');
var createMessageIOEmitter = require('./createMessageIOEmitter');
var logError = require('./logError');

var coapServer = function(config, parentConnection){
  var socketEmitter = createMessageIOEmitter();

  var sendMessage = sendMessageCreator(socketEmitter, _.noop, parentConnection);
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
    socketEmitter(device.uuid, topic, msg);
  }

  var skynet = {
    sendMessage: sendMessage,
    sendActivity: sendActivity,
    throttles: throttles,
    emitToClient: emitToClient
  };

  setupCoapRoutes(coapRouter, skynet);

  coapServer.on('request', coapRouter.process);
  coapServer.on('error', logError);

  var coapPort = coapConfig.port || 5683;
  var coapHost = coapConfig.host || 'localhost';

  coapServer.listen(coapPort, function () {
    console.log('CoAP listening at coap://' + coapHost + ':' + coapPort);
  });
}

module.exports = coapServer;
