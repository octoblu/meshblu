var _ = require('lodash');
var whoAmI = require('./whoAmI');
var logEvent = require('./logEvent');
var sendYo = require('./sendYo');
var sendSms = require('./sendSms');
var securityImpl = require('./getSecurityImpl');
var sendActivity = require('./sendActivity');
var createActivity = require('./createActivity');
var wrapMqttMessage = require('./wrapMqttMessage');
var sendPushNotification = require('./sendPushNotification');

var DEFAULT_QOS = 0;

function publishActivity(topic, fromDevice, toDevice){
  if(fromDevice && fromDevice.ipAddress){
    sendActivity(createActivity(topic, fromDevice.ipAddress, fromDevice, toDevice));
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
        console.log('error forwarding message', ex);
      }
    }
  }

  function broadcastMessage(data, topic, fromUuid, fromDevice){
    var devices = data.devices;

    if(!isBroadcast(devices, topic)){ return; }

    //broadcasting should never require responses
    delete data.ack;

    var broadcastType = topic === 'tb' ? '_tb' : '_bc';
    socketEmitter(fromUuid + broadcastType, topic, data);
    mqttEmitter(fromUuid + broadcastType, wrapMqttMessage(topic, data), {qos: data.qos || DEFAULT_QOS});
    publishActivity(topic, fromDevice);
    logEvent(300, data);
  };

  var sendMessage = function(device, data, topic, fromUuid, fromDevice, toDevices){
    if( isBroadcast([device], topic) ) {
      return;
    }
    var toDeviceProp = device;
    if (device.length > 35){

      var deviceArray = device.split('/');
      if(deviceArray.length > 1){
        device = deviceArray.shift();
        toDeviceProp = deviceArray.join('/');
      }

      //check devices are valid
      whoAmI(device, false, function(check){
        var clonedMsg = cloneMessage(data, toDeviceProp, fromUuid);
        if(topic === 'tb'){
          delete clonedMsg.devices;
        }

        if(!check.error){
          if(securityImpl.canSend(fromDevice, check)){

            publishActivity(topic, fromDevice, check);

            // //to phone, but not from same phone
            if(check.phoneNumber && check.type === "outboundSMS"){
              // SMS handler
              sendSms(device, JSON.stringify(clonedMsg.payload), function(sms){
                var logMsg = _.clone(clonedMsg);
                logMsg.toUuid = check; // add to device object to message for logging
                logEvent(302, logMsg);
              });
            }else if(check.yoUser && check.type === "yo"){
              // Yo handler
              sendYo(device, function(yo){
                var logMsg = _.clone(clonedMsg);
                logMsg.toUuid = check; // add to device object to message for logging
                logEvent(304, logMsg);
              });
            }else if(check.type === 'octobluMobile'){
              // Push notification handler
              sendPushNotification(check, JSON.stringify(clonedMsg.payload), function(push){
                var logMsg = _.clone(clonedMsg);
                logMsg.toUuid = check; // add to device object to message for logging
                logEvent(305, logMsg);
              });
            }

            var emitMsg = clonedMsg;

            // Added to preserve to devices in message
            emitMsg.devices = toDevices;
            
            if(check.payloadOnly){
              emitMsg = clonedMsg.payload;
            }

            if(check.protocol === 'mqtt'){
              mqttEmitter(check.uuid, wrapMqttMessage(topic, emitMsg), {qos: data.qos || DEFAULT_QOS});
            }
            else{
              socketEmitter(check.uuid, topic, emitMsg);
            }
          }else{
            clonedMsg.UNAUTHORIZED=true; //for logging
          }

        }else{
          forwardMessage(clonedMsg);
        }

        var logMsg = _.clone(clonedMsg);
        logMsg.toUuid = check; // add to device object to message for logging
        logEvent(300, logMsg);
      });
    }
  };

  var isBroadcast = function(devices, topic){
    return _.contains(devices, '*') || _.contains(devices, 'all') || (topic === 'tb' && _.isEmpty(devices));
  };

  return function(fromDevice, data, topic){
    topic = topic || 'message';
    var fromUuid;
    if(fromDevice){
      fromUuid = fromDevice.uuid;
    }

    if(fromUuid){
      data.fromUuid = fromUuid;
    }

    if(data.token){
      //never forward token to another client
      delete data.token;
    }

    broadcastMessage(data, topic, fromUuid, fromDevice);

    if(!data.devices) {
      return;
    }

    var devices = data.devices;
    if( typeof devices === 'string' ) {
      devices = [ devices ];
    }

    //cant ack to multiple devices
    if(devices.length > 1){
      delete data.ack;
    }

    devices.forEach( function(device) {
      sendMessage(device, data, topic, fromUuid, fromDevice, data.devices);
    });
  };
}

module.exports = createMessageSender;

