var _      = require('lodash');
var moment = require('moment');
var whoAmI = require('./whoAmI');
var config = require('./../config');
var devices = require('./database').devices;
var clearCache = require('./clearCache');
var authDevice = require('./authDevice');

function respond(uuid, callback){
  whoAmI(uuid, true, function(check){
    var result = {uuid: uuid};
    if(!check.error){
      result.status = 201;
      result.device = check;
      callback(result);
    }else{
      result.status = 401;
      callback(result);
    }
  });
}

module.exports = function(socket, callback) {
  var uuid, token;

  socket = _.clone(socket);

  uuid = socket.uuid;
  delete socket['uuid'];
  token = socket.token;
  delete socket['token'];

  socket = _.omit(socket, function(value, key){
    // Mongo won't store $'d keys, so we don't either.
    return key[0] === '$';
  });

  socket.timestamp = moment(new Date().getTime()).toISOString();

  if (!uuid && !token) {
    // auto-register device if UUID not provided on authentication
    var registerDevice = require('./register');

    socket.autoRegister = true;

    registerDevice(socket, function(results){
      respond(results.uuid, callback);
    });
    return;
  }

  clearCache('DEVICE_'+uuid);

  if(uuid && !token){
    callback({uuid: uuid, status: 401});
    return;
  } 

  if (_.isUndefined(socket.online)) {
    socket.online = true
  }

  if (socket.ipAddress){
    try {
      var geoip = require('geoip-lite');
      socket.geo = geoip.lookup(socket.ipAddress);
    } catch(error){
      if (error) {
        console.error(error);
      }
    }
  }

  authDevice(uuid, token, function(error, device) {
    if (error) {
      console.error(error);
      callback({uuid: uuid, status: 401});
      return;
    }

    devices.update({uuid: uuid}, {$set: socket}, function(err, saved) {
      if(err) {
        console.error(err);
        callback({uuid: uuid, status: 401});
      } else if(!saved) {
        console.log('Device Not Saved: ', saved);
        callback({uuid: uuid, status: 401});
      } else if(config.mongo && config.mongo.databaseUrl && !saved.updatedExisting) {
        console.log('Device Not Existing: ', saved);
        callback({uuid: uuid, status: 401});
      } else {
        respond(uuid, callback);
      }
    });
  });
};
