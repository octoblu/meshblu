var config = require('./../config');

if(config.mongo){
  var devices = require('./database').collection('devices');
} else {
  var devices = require('./database').devices;
}

module.exports = function(phone, callback) {
  devices.findOne({
    phoneNumber: phone
  }, function(err, devicedata) {
    if(err || !devicedata || devicedata.length < 1) {
      console.log('phone number not found');
      callback('phone number not found');
    } else {
      console.log('UUID: ' + devicedata.uuid);
      callback(null, devicedata);
    }
  });
};
