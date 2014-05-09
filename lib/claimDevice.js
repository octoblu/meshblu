var update = require('./updateDevice');
var devices = require('./database').collection('devices');
var whoAmI = require('./whoAmI');
var securityImpl = require('./getSecurityImpl');

module.exports = function(fromDevice, claimUuid, callback) {

  if(!fromDevice || !claimUuid){
    callback(new Error('invalid from or to device'));
  }
  else{
    whoAmI(claimUuid, false, function(toDevice){
      if(toDevice.error){
        callback(new Error('invalid device to claim'));
      }
      else{
        if(securityImpl.canUpdate(fromDevice, toDevice)){
          devices.update({uuid: claimUuid}, {$set: {owner: fromDevice.uuid} }, callback);
        }
        else{
          callback(new Error('unauthorized'));
        }
      }
    });
  }

};
