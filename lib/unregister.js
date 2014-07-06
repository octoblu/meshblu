var config = require('./../config');

var devices = require('./database').devices;
var whoAmI = require('./whoAmI');
var securityImpl = require('./getSecurityImpl');

module.exports = function(fromDevice, unregisterUuid, callback) {

  if(!fromDevice || !unregisterUuid){
    callback('invalid from or to device');
  }
  else{
    whoAmI(unregisterUuid, false, function(toDevice){
      if(toDevice.error){
        callback('invalid device to unregister');
      }
      else{
        if(securityImpl.canUpdate(fromDevice, toDevice)){

          devices.remove({
            uuid: unregisterUuid
          }, function(err, devicedata) {

            if(err || devicedata === 0) {

              callback({
                  "message": "Device not found or token not valid",
                  "code": 404
                });


            } else {
              console.log('Device unregistered: ' + unregisterUuid);

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
