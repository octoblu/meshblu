var _ = require('lodash');
var config = require('./../config');

if (config.redis && config.redis.host) {
  module.exports = require('./clearCacheRedis');
} else {
  module.exports = function(uuid, callback) {
    if(callback) {
      callback();
    }
  }
}
