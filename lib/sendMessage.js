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


function createMessageSender(socketEmitter, mqttEmitter){

  return function(fromDevice, data, topic){
    topic = topic || 'message';
    var fromUuid;
    if(fromDevice){
      fromUuid = fromDevice.uuid;
    }

    console.log("sendMessage() from", fromUuid, data);

    if(fromUuid){
      data.fromUuid = fromUuid;
    }

    if(data.token){
      //never forward token to another client
      delete data.token;
    }


      console.log('devices: ' + data.devices);
      console.log('message: ' + JSON.stringify(data));
      //console.log('protocol: ' + data.protocol); <- dont think this makes sense

      var devices = data.devices;


      if(devices === "all" || devices === "*" || (topic === 'tb' && !devices)){

        //broadcasting should never require responses
        delete data.ack;

        var broadcastType = topic === 'tb' ? '_tb' : '_bc';
        socketEmitter(fromUuid + broadcastType, topic, data);
        mqttEmitter(fromUuid + broadcastType, wrapMqttMessage(topic, data), {qos: data.qos || DEFAULT_QOS});
        publishActivity(topic, fromDevice);
        logEvent(300, data);

      } else {

        if(devices){

          if( typeof devices === 'string' ) {
            devices = [ devices ];
          }

          //cant ack to multiple devices
          if(devices.length > 1){
            delete data.ack;
          }

          devices.forEach( function(device) {
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


                //console.log('device check:', check);
                if(!check.error){
                  if(securityImpl.canSend(fromDevice, check)){

                    publishActivity(topic, fromDevice, check);

                    // //to phone, but not from same phone
                    // if(check.phoneNumber && (clonedMsg.fromPhone !== check.phoneNumber)){
                    if(check.phoneNumber && check.type === "outboundSMS"){
                      // SMS handler
                      console.log("Sending SMS to", check.phoneNumber);
                      sendSms(device, JSON.stringify(clonedMsg.payload), function(sms){
                        var logMsg = _.clone(clonedMsg);
                        logMsg.toUuid = check; // add to device object to message for logging
                        logEvent(302, logMsg);
                        console.log('Sent SMS!', device, check.phoneNumber);
                      });
                    }else if(check.yoUser && check.type === "yo"){
                      // Yo handler
                      sendYo(device, function(yo){
                        var logMsg = _.clone(clonedMsg);
                        logMsg.toUuid = check; // add to device object to message for logging
                        logEvent(304, logMsg);
                        console.log('Sent Yo!', device, check.yoUser);
                      });
                    }else if(check.type === 'octobluMobile'){
                      // Push notification handler
                      console.log("Sending Push Notification to", check.uuid);
                      sendPushNotification(check, JSON.stringify(clonedMsg.payload), function(push){
                        var logMsg = _.clone(clonedMsg);
                        logMsg.toUuid = check; // add to device object to message for logging
                        logEvent(305, logMsg);
                        console.log('Sent Push Notification!', device);
                      });
                    }

                    var emitMsg = clonedMsg;
                    if(check.payloadOnly){
                      emitMsg = clonedMsg.payload;
                    }

                    console.log('\nemitting', check.uuid, emitMsg, topic);

                    if(check.protocol === 'mqtt'){
                      mqttEmitter(check.uuid, wrapMqttMessage(topic, emitMsg), {qos: data.qos || DEFAULT_QOS});
                    }
                    else{
                      socketEmitter(check.uuid, topic, emitMsg);
                    }


                  }else{
                    clonedMsg.UNAUTHORIZED=true; //for logging
                    console.log('unauthorized send attempt from', fromUuid, 'to', device);
                  }

                }else{
                  clonedMsg.INVALID_DEVICE=true; //for logging
                  console.log('send attempt on invalid device from', fromUuid, 'to', device);
                  //forward the message upward the tree
                  //forwardMessage(cloneMessage, fn);
                }

                var logMsg = _.clone(clonedMsg);
                logMsg.toUuid = check; // add to device object to message for logging
                logEvent(300, logMsg);

              });

            }

          });

        }

      }

  };

}

module.exports = createMessageSender;

