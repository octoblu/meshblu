var config = require('./../config');

// Connect to MongoHQ
// http://howtonode.org/node-js-and-mongodb-getting-started-with-mongojs
// var databaseUrl = config.databaseUrl; //Example using MongoHQ: [USER]:[PASSWORD]@staff.mongohq.com:[PORT]/[APP]
var mongojs = require('mongojs');
module.exports = mongojs(config.databaseUrl);