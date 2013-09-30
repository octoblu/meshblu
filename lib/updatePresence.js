var devices = require('./database').collection('devices');

module.exports = function(socket) {

  var newTimestamp = new Date().getTime();
  console.log('socket: ' + socket);

  devices.update({
    socketId: socket
  }, {
    $set: {online: false}
  }, function(err, saved) {
    if(err || saved == 0) {
      console.log('Device not found for socket: ' + socket);
      return
    } else {
      console.log('Device went offline: ' + socket);
      return      
    }
  });

};