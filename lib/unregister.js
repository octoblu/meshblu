var config = require('./../config');
var socketEmitter = require('./createSocketEmitter')();

var devices = require('./database').devices;
var whoAmI = require('./whoAmI');
var securityImpl = require('./getSecurityImpl');

module.exports = function(fromDevice, unregisterUuid, unregisterToken, emitToClient, callback) {

  if(!fromDevice || !unregisterUuid) {
    return callback('invalid from or to device');
  }

  whoAmI(unregisterUuid, true, function(toDevice){
    if(toDevice.error){
      return callback('invalid device to unregister');
    }

    if(!securityImpl.canConfigure(fromDevice, toDevice)){
      return callback({message:'unauthorized', code: 401});
    }

    if (emitToClient) {
      emitToClient('unregistered', toDevice, toDevice);
    } else {
      socketEmitter(toDevice.uuid, 'unregistered', toDevice);
    }

    devices.remove({ uuid: unregisterUuid }, function(err, devicedata) {
      if(err || devicedata === 0) {
        callback({ "message": "Device not found or token not valid", "code": 404});
        return;
      }
      callback( null, {uuid: unregisterUuid} );
    });
    
  });
};
