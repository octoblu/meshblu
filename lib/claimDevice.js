var update = require('./updateDevice');
var devices = require('./database').collection('devices');
var whoAmI = require('./whoAmI');
var securityImpl = require('./getSecurityImpl');

module.exports = function(fromDevice, data, callback) {

  if(!fromDevice || !data || !data.claimUuid){
    callback(new Error('invalid from or to device'));
  }
  else{
    whoAmI(data.claimUuid, false, function(toDevice){
      if(toDevice.error){
        callback(new Error('invalid device to claim'));
      }
      else{
        if(securityImpl.canUpdate(fromDevice, toDevice)){
          var updateFields = {owner: fromDevice.uuid};
          if(data.name){
            updateFields.name = data.name;
          }
          console.log('updateFields', updateFields);
          devices.update({uuid: data.claimUuid}, {$set: updateFields }, callback);
        }
        else{
          callback(new Error('unauthorized'));
        }
      }
    });
  }

};
