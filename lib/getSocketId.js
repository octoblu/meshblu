var devices = require('./database').collection('devices');

module.exports = function(uuid, callback) {
  devices.findOne({
    uuid: {"$regex":uuid,"$options":"i"}
  }, function(err, devicedata) {
    if(err || !devicedata || devicedata.length < 1) {
      console.log('uuid not found');
      callback({});
    } else {
      console.log('socketid: ' + devicedata.socketId);
      callback(devicedata.socketId);
    }
  });
};

