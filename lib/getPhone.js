var devices = require('./database').collection('devices');

module.exports = function(phone, callback) {
  devices.findOne({
    phoneNumber: {"$regex":phone,"$options":"i"}
  }, function(err, devicedata) {
    if(err || !devicedata || devicedata.length < 1) {
      console.log('phone number not found');
      callback({});
    } else {
      console.log('UUID: ' + devicedata.uuid);
      callback(devicedata.uuid);
    }
  });
};

