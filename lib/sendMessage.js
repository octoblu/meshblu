var _ = require('lodash');
var config = require('../config');
var getDevice = require('./getDevice');
var logEvent = require('./logEvent');
var sendYo = require('./sendYo');
var sendSms = require('./sendSms');
var securityImpl = require('./getSecurityImpl');
var sendActivity = require('./sendActivity');
var createActivity = require('./createActivity');
var sendPushNotification = require('./sendPushNotification');
var debug = require('debug')('meshblu:sendMessage');
var doMessageHooks = require('./doMessageHooks');
var doMessageForward = require('./doMessageForward');
var getSubscriptions = require('./getSubscriptions');
var logError = require('./logError');
var async = require('async');
var Benchmark = require('simple-benchmark');
var Publisher = require('./Publisher');
var publisher = new Publisher

var DEFAULT_QOS = 0;

function publishActivity(topic, fromDevice, toDevice, data){
  if(fromDevice && fromDevice.ipAddress){
    sendActivity(createActivity(topic, fromDevice.ipAddress, fromDevice, toDevice, data));
  }
}

function cloneMessage(msg, device, fromUuid){
  if(typeof msg === 'object'){
    var clonedMsg = _.clone(msg);
    clonedMsg.devices = device; //strip other devices from message
    delete clonedMsg.protocol;
    delete clonedMsg.api;
    clonedMsg.fromUuid = msg.fromUuid; // add from device object to message for logging
    return clonedMsg;
  }

  return msg;
}


function createMessageSender(socketEmitter, mqttEmitter, parentConnection){

  function forwardMessage(message){
    if(parentConnection && message){
      try{
        message.originUuid = message.fromUuid;
        delete message.fromUuid;
        parentConnection.message(message);
      }catch(ex){
        logError(ex, 'error forwarding message');
      }
    }
  }

  function messageForward(toDevice, emitMsg, callback){
    var benchmark = new Benchmark({label: 'messageForward'});
    if (!toDevice.meshblu) {
      return callback()
    }
    doMessageHooks(toDevice, toDevice.meshblu.messageHooks, emitMsg, function(error) {
      doMessageForward(toDevice.meshblu.messageForward, emitMsg, toDevice.uuid, function(error, messages) {
        async.each(messages, function(msg, done){
          getDevice(msg.forwardTo, function(error, forwardDevice) {
            if(error) {
              logError(error);
              return done();
            }
            if(!forwardDevice) {
              logError('sendMessage.js: forwardDevice not found');
              return done();
            }
            sendMessage(forwardDevice.uuid, msg.message, msg.topic, toDevice.uuid, toDevice, [forwardDevice.uuid], done);
          });
        }, function(){
          debug(benchmark.toString());
          callback();
        });
      });
    });
  }

  function broadcastMessage(data, topic, fromUuid, fromDevice, callback){
    var devices = data.devices;

    if(!isBroadcast(devices, topic)){ return callback(); }

    //broadcasting should never require responses
    delete data.ack;

    publishActivity(topic, fromDevice, null, data);
    var logMsg = _.clone(data);
    logMsg.from = _.pick(_.clone(fromDevice), config.preservedDeviceProperties);
    logEvent(300, logMsg);

    async.parallel([
      async.apply(publisher.publish, 'broadcast', fromUuid, data),
      async.apply(publisher.publish, 'sent', fromUuid, data),
      async.apply(sendStateFullBroadcasts, fromUuid, data)
    ], callback);
  };

  var sendStateFullBroadcasts = function(fromUuid, data, callback){
    getSubscriptions(fromUuid, 'broadcast', function(error, toUuids){
      if(error) {
        logError(error);
        return callback();
      }
      async.each(toUuids, function(uuid, done){
        async.parallel([
          async.apply(publisher.publish, 'broadcast', uuid, data),
          async.apply(handleForwardMessage, uuid, data)
        ], done);
      }, callback);
    });
  }

  var handleForwardMessage = function(uuid, data, callback) {
    getDevice(uuid, function(error, device){
      if(error) {
        logError(error);
        return callback();
      }
      messageForward(device, data, callback);
    });
  }

  var sendMessages = function(devices, data, topic, fromUuid, fromDevice, toDevices, callback){
    async.each(devices, function(device, done){
      sendMessage(device, data, topic, fromUuid, fromDevice, data.devices, done);
    }, callback);
  };

  var sendMessage = function(device, data, topic, fromUuid, fromDevice, toDevices, callback){
    var benchmark = new Benchmark({label: 'sendMessage'});
    if (!device) {
      return callback();
    }

    if( isBroadcast([device], topic) ) {
      return callback();
    }

    var toDeviceProp = device;
    // if (device.length > 35){
    if (device.length <= 0){
      return callback();
    }

    var deviceArray = device.split('/');
    if(deviceArray.length > 1){
      device = deviceArray.shift();
      toDeviceProp = deviceArray.join('/');
    }

    // check devices are valid
    getDevice(device, function(error, check) {
      var clonedMsg = cloneMessage(data, toDeviceProp, fromUuid);

      if(error){
        clonedMsg.UNAUTHORIZED=true; //for logging
        forwardMessage(clonedMsg);
        return callback();
      }

      if(topic === 'tb'){
        delete clonedMsg.devices;
      }

      securityImpl.canSend(fromDevice, check, function(error, permission){
        publishActivity(topic, fromDevice, check, data);
        var emitMsg = clonedMsg;

        if(error || !permission){
          clonedMsg.UNAUTHORIZED=true; //for logging
          forwardMessage(clonedMsg);
          return callback();
        }

        // Added to preserve to devices in message
        emitMsg.devices = toDevices;

        if(check.payloadOnly){
          emitMsg = clonedMsg.payload;
        }

        var logMsg = _.clone(clonedMsg);
        logMsg.toUuid = check.uuid;
        logMsg.to = _.pick(check, config.preservedDeviceProperties);
        logMsg.from = _.pick(fromDevice, config.preservedDeviceProperties);
        logEvent(300, logMsg);

        debug(benchmark.toString());

        async.parallel([
          async.apply(publisher.publish, 'sent', fromDevice.uuid, data),
          async.apply(publisher.publish, 'received', device, data),
          async.apply(messageForward, check, emitMsg)
        ], callback);
      });
    });
  };

  var isBroadcast = function(devices, topic){
    return _.contains(devices, '*') || _.contains(devices, 'all') || (topic === 'tb' && _.isEmpty(devices));
  };

  return function(fromDevice, data, topic, callback){
    var benchmark = new Benchmark({label: 'curried-function'});
    data = _.clone(data);
    if(!data.devices) {
      callback(new Error('Invalid Message Format'));
      return;
    }

    topic = topic || 'message';

    var fromUuid;
    if(fromDevice){
      fromUuid = fromDevice.uuid;
    }

    if(fromUuid){
      data.fromUuid = fromUuid;
    }

    delete data.token;


    var devices = data.devices;
    if( typeof devices === 'string' ) {
      devices = [ devices ];
    }

    //cant ack to multiple devices
    if(devices.length > 1){
      delete data.ack;
    }

    debug(benchmark.toString())
    async.parallel([
      async.apply(broadcastMessage, data, topic, fromUuid, fromDevice),
      async.apply(sendMessages, devices, data, topic, fromUuid, fromDevice, data.devices)
    ], callback);
  };
}

module.exports = createMessageSender;
