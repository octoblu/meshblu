var config = require('./../config');

var devices = require('./database').devices;

module.exports = function(phone, callback) {
  devices.findOne({
    phoneNumber: phone
  }, function(err, devicedata) {
    if(err || !devicedata || devicedata.length < 1) {
      callback('phone number not found');
    } else {
      callback(null, devicedata);
    }
  });
};
