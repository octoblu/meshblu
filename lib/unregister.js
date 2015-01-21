var config = require('./../config');
var socketEmitter = require('./createSocketEmitter')();

var devices = require('./database').devices;
var whoAmI = require('./whoAmI');
var securityImpl = require('./getSecurityImpl');

module.exports = function(fromDevice, unregisterUuid, unregisterToken, emitToClient, callback) {

  if(!fromDevice || !unregisterUuid){
    callback('invalid from or to device');
  }
  else{
    whoAmI(unregisterUuid, true, function(toDevice){
      if(toDevice.error){
        callback('invalid device to unregister');
      }
      else{
        if((unregisterToken && toDevice.token === unregisterToken) || securityImpl.canConfigure(fromDevice, toDevice)){
          if (emitToClient) {
            emitToClient('unregistered', toDevice, toDevice);
          } else {
            socketEmitter(toDevice.uuid, 'unregistered', toDevice);
          }
          devices.remove({
            uuid: unregisterUuid
          }, function(err, devicedata) {
            if(err || devicedata === 0) {
              callback({
                  "message": "Device not found or token not valid",
                  "code": 404
                });
            } else {
              callback(null, {
                uuid: unregisterUuid
              });
            }
          });
        }
        else{
          callback({message:'unauthorized', code: 401});
        }
      }
    });
  }
};
