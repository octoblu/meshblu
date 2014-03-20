var config = require('./../config');
var mongojs = require('mongojs');
module.exports = mongojs(config.databaseUrl);
