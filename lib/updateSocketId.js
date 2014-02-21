var devices = require('./database').collection('devices');

module.exports = function(socket, callback) {

  var newTimestamp = new Date().getTime();
  console.log("update socket: " + JSON.stringify(socket));
  if(socket.uuid && socket.token){

    devices.update({
      uuid: {"$regex":socket.uuid,"$options":"i"}, token: socket.token
    }, {
      $set: {socketId: socket.socketid, online: true, timestamp: newTimestamp, ipAddress: socket.ipAddress}
    }, function(err, saved) {
      if(err || saved === 0) {
        console.log('Device not found or token not valid for: ' + socket.uuid);
        console.log('Error: ' + err);
        callback({uuid: socket.uuid, status: 401});

      } else {
        console.log('SocketId and presence updated for device: ' + socket.uuid);
        callback({uuid: socket.uuid, status: 201});
      }

    });

  } else {

    if(socket.uuid){
      callback({uuid: socket.uuid, status: 401});
    } else {
      // auto-register device if UUID not provided on authentication
      require('./register')({"autoRegister":true, socketId: socket.socketid, online: true, timestamp: newTimestamp, ipAddress: socket.ipAddress}, function(results){
        console.log('Device auto-registered: ' + results.uuid)
        console.log(results);
        callback({uuid: results.uuid, token: results.token, status: 201});
      });
    }

  }

};