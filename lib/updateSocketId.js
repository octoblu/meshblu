var devices = require('./database').collection('devices');

module.exports = function(socket) {

  var newTimestamp = new Date().getTime();

  devices.update({
    uuid: socket.uuid
  }, {
    $set: {socketId: socket.socketid, online: true}
  }, function(err, saved) {
    console.log('SocketId and presence updated for device: ' + socket.uuid);
    return
  });

};