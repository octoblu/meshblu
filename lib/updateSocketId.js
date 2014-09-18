var moment = require('moment');
var whoAmI = require('./whoAmI');
var config = require('./../config');

var devices = require('./database').devices;

var clearCache = require('./clearCache');

function respond(uuid, callback, sendToken){
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
  if(socket.uuid && socket.token){
    clearCache('DEVICE_'+socket.uuid);

    if (socket.ipAddress){
      try {
        var geoip = require('geoip-lite');        
        var geo = geoip.lookup(socket.ipAddress);
      } catch(geoip){
        var geo = null;
      }
    } else {
      var geo = null;
    }

    devices.update({
      uuid: socket.uuid, token: socket.token
    }, {
      $set: {socketid: socket.socketid, online: true, timestamp: moment(newTimestamp).toISOString(), ipAddress: socket.ipAddress, geo: geo, protocol: socket.protocol, secure: socket.secure}
    }, function(err, saved) {

      if(err || saved === 0 || (saved && config.mongo && config.mongo.databaseUrl && !saved.updatedExisting)) {
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
        respond(results.uuid, callback, true);
      });
    }

  }

};
