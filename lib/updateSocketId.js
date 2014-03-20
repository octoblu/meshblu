var devices = require('./database').collection('devices');
var moment = require('moment');

module.exports = function(socket, callback) {

  var newTimestamp = new Date().getTime();
  console.log("update socket: " + JSON.stringify(socket));
  if(socket.uuid && socket.token){

    devices.update({
      uuid: socket.uuid, token: socket.token
    }, {
      $set: {socketId: socket.socketid, online: true, timestamp: moment(newTimestamp).toISOString(), ipAddress: socket.ipAddress, protocol: socket.protocol}
    }, function(err, saved) {

      console.log('SAVED', saved);

      if(err || saved === 0 || (saved && !saved.updatedExisting)) {
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
      require('./register')({"autoRegister":true, socketId: socket.socketid, online: true, timestamp: moment(newTimestamp).toISOString(), ipAddress: socket.ipAddress}, function(results){
        console.log('Device auto-registered: ' + results.uuid)
        console.log(results);
        callback({uuid: results.uuid, token: results.token, status: 201});
      });
    }

  }

};
