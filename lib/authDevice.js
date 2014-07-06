// var devices = require('./database').collection('devices');
var config = require('./../config');
var devices = require('./database').devices;

module.exports = function(uuid, token, callback) {

  if(!uuid && !token){
    return callback({'authenticate': false});
  }

  devices.findOne({
    uuid: uuid, token: token
  }, function(err, devicedata) {
    if(err || !devicedata || devicedata.length < 1) {
      // console.log('uuid not found');
      return callback({'authenticate': false});
    } else {
      // console.log('uuid and token authenticated');
      return callback({'authenticate': true, device: devicedata});
    }
  });

};
