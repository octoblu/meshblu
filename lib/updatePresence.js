var devices = require('./database').collection('devices');

module.exports = function(socket) {
  devices.update({
    socketId: socket
  }, {
    $set: {online: false}
  }, function(err, saved) {
    if(err || saved === 0) {
      console.log('Device not found for socket: ' + socket);
      return;
    } else {
      console.log('Device went offline: ' + socket);
      require('./logEvent')(401, {socketid: socket, online: false});
      return;
    }
  });

};