var config = require('./../config');
var path = require('path');

if(config.mongo && config.mongo.databaseUrl){

  var mongojs = require('mongojs');
  var db = mongojs(config.mongo.databaseUrl);
  module.exports = {
    devices: db.collection('devices'),
    events: db.collection('events'),
    data: db.collection('data'),
    subscriptions: db.collection('subscriptions')
  };

  db.on('error', function (err) {
    if (/ECONNREFUSED/.test(err.message) ||
     /no primary server available/.test(err.message)) {
      console.error('FATAL: database error', err);
      process.exit(1);
    }
  })

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

  var subscriptions = new Datastore({
    filename: path.join(__dirname, '/../subscriptions.db'),
    autoload: true }
  );

  module.exports = {
    devices: devices,
    events: events,
    data: data,
    subscriptions: subscriptions
  };
}
