var devices = require('./database').collection('devices');
var moment = require('moment');
var whoAmI = require('./whoAmI');


function respond(uuid, callback, sendToken){
  console.log('SocketId and presence updated for device: ' + uuid);

  whoAmI(uuid, true, function(check){
    var result = {uuid: uuid};
    if(!check.error){
      result.status = 201;
      result.device = check;
      if(sendToken){
        result.token = check.token;
      }
      callback(result);
    }else{
      result.status = 401;
      callback(result);
    }

  });
}

module.exports = function(socket, callback) {

  var newTimestamp = new Date().getTime();
  console.log("update socket: " + JSON.stringify(socket));
  if(socket.uuid && socket.token){

    devices.update({
      uuid: socket.uuid, token: socket.token
    }, {
      $set: {socketid: socket.socketid, online: true, timestamp: moment(newTimestamp).toISOString(), ipAddress: socket.ipAddress, protocol: socket.protocol, secure: socket.secure}
    }, function(err, saved) {

      console.log('SAVED', saved);

      if(err || saved === 0 || (saved && !saved.updatedExisting)) {
        console.log('Device not found or token not valid for: ' + socket.uuid);
        console.log('Error: ' + err);
        callback({uuid: socket.uuid, status: 401});

      } else {
        respond(socket.uuid, callback);
      }

    });

  } else {

    if(socket.uuid){
      callback({uuid: socket.uuid, status: 401});
    } else {
      // auto-register device if UUID not provided on authentication
      require('./register')({"autoRegister":true, socketid: socket.socketid, online: true, timestamp: moment(newTimestamp).toISOString(), ipAddress: socket.ipAddress, protocol: socket.protocol, secure: socket.secure}, function(results){
        console.log('Device auto-registered: ' + results.uuid);
        respond(results.uuid, callback, true);
      });
    }

  }

};
