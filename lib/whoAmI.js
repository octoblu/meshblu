var config = require('./../config');
var getDevice = require('./getDevice');

module.exports = function(uuid, owner, callback) {
  getDevice(uuid, function(error, device) {
    if (!device) {
      device = {};
    }
    device.error = error; 
    callback(device);
  });
};
