var devices = require('./database').collection('devices');

module.exports = function(socket, callback) {

  var newTimestamp = new Date().getTime();

  devices.update({
    uuid: {"$regex":socket.uuid,"$options":"i"}, token: socket.token
  }, {
    $set: {socketId: socket.socketid, online: true, timestamp: newTimestamp}
  }, function(err, saved) {

    if(err || saved == 0) {
      console.log('Device not found or token not valid for: ' + socket.uuid);
      callback({uuid: socket.uuid, status: 401});
    } else {
      console.log('SocketId and presence updated for device: ' + socket.uuid);
      callback({uuid: socket.uuid, status: 201});
    }

  });

};