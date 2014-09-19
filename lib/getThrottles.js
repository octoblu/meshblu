'use strict';

var tokenthrottle = require("tokenthrottle");
var config = require('../config');

config.rateLimits = config.rateLimits || {};
// rate per second
var throttles = {
  connection : tokenthrottle({rate: config.rateLimits.connection || 3}),
  message : tokenthrottle({rate: config.rateLimits.message || 10}),
  data : tokenthrottle({rate: config.rateLimits.data || 10}),
  query : tokenthrottle({rate: config.rateLimits.query || 2}),
  whoami : tokenthrottle({rate: config.rateLimits.whoami || 10}),
  unthrottledIps : config.rateLimits.unthrottledIps || []
};

module.exports = throttles;