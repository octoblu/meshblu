var devices = require('./database').collection('devices');

module.exports = function(socket, callback) {
  console.log('getUuid socket info:', socket);
  devices.findOne({
    socketid: socket
  }, function(err, devicedata) {
    // console.log('getuuid', err, devicedata);
    console.log('getuuid', socket, err, devicedata);
    if(err || !devicedata || devicedata.length < 1) {
      console.log('socket not found');
      callback(new Error('uuid not found for socket' + socket), null);
    } else {
      console.log('UUID: ' + devicedata.uuid);
      callback(null, devicedata.uuid);
    }
  });
};
