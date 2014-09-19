var config = require('./../config');

var devices = require('./database').devices;

module.exports = function(uuid, callback) {
  devices.findOne({
    uuid: uuid
  }, function(err, devicedata) {
    if(err || !devicedata || devicedata.length < 1) {
      callback({});
    } else {
      callback(devicedata.socketid);
    }
  });
};
