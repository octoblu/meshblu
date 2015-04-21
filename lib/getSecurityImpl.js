var config = require('./../config');

var securityModule;
if (config.securityImpl) {
  securityModule = require(config.securityImpl);
} else {
  SimpleAuth = require('../lib/simpleAuth');
  securityModule = new SimpleAuth
}

module.exports = securityModule;
