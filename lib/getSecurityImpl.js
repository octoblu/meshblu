var config = require('./../config');

var securityModuleName = config.securityImpl || './../lib/simpleAuth';

module.exports = require(securityModuleName);
