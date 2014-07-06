var update = require('./updateDevice');
var whoAmI = require('./whoAmI');
var securityImpl = require('./getSecurityImpl');
var config = require('./../config');

var devices = require('./database').devices;

module.exports = function(fromDevice, data, callback) {

  console.log('claiming from', fromDevice, 'to', data);

  if(!fromDevice || !data || !data.uuid){
    callback('invalid from or to device');
  }
  else{
    whoAmI(data.uuid, false, function(toDevice){
      if(toDevice.error){
        callback('invalid device to claim');
      }
      else{
        if(securityImpl.canUpdate(fromDevice, toDevice)){
          var updateFields = {owner: fromDevice.uuid};
          if(data.name){
            updateFields.name = data.name;
          }
          console.log('updateFields', updateFields);
          devices.update({uuid: data.uuid}, {$set: updateFields }, callback);
        }
        else{
          callback('unauthorized');
        }
      }
    });
  }

};
