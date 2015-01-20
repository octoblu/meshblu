var config = require('./../config');
var getDevice = require('./getDevice');

module.exports = function(uuid, owner, callback) {
  getDevice(uuid, callback);
};
