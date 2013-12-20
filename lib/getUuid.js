var devices = require('./database').collection('devices');

module.exports = function(socket, callback) {
  devices.findOne({
    socketId: {"$regex":socket,"$options":"i"}
  }, function(err, devicedata) {
    if(err || !devicedata || devicedata.length < 1) {
      console.log('socket not found');
      callback({});
    } else {
      console.log('UUID: ' + devicedata.uuid);
      callback(devicedata.uuid);
    }
  });
};

