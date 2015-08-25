var _ = require('lodash');
var config = require('./../config');
var devices = require('./database').devices;
var Device = require('./models/device');

module.exports = function(socket, callback) {
  callback = callback || _.noop;
  devices.findOne({ socketid: socket }, function(error, device) {
    if (error) {
      return callback(error);
    }
    if (!device) {
      return callback(new Error('Device Not Found'));
    }

    var device = new Device(device);
    device.update({$set: {online: false}}, function(error){
      if (error) {
        return callback(error);
      }

      callback();
    });
  });
}
