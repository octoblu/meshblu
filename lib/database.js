var config = require('./../config');
var path = require('path');

if(config.mongo){

  var mongojs = require('mongojs');
  module.exports = mongojs(config.mongo.databaseUrl);

} else {

  var Datastore = require('nedb');
  var devices = new Datastore({
    filename: path.join(__dirname, '/../devices.db'),
    autoload: true }
  );
  var events = new Datastore({
    filename: path.join(__dirname, '/../events.db'),
    autoload: true }
  );
  var data = new Datastore({
    filename: path.join(__dirname, '/../data.db'),
    autoload: true }
  );

  module.exports = {
    devices: devices,
    events: events,
    data: data
  };
}
