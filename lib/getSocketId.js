var getDevice = require('./getDevice');
module.exports = function(uuid, callback) {
  getDevice(uuid, function(error, device) {
    if (error) {
      callback({});
      return;
    }

    callback(device.socketid);
  });
};
