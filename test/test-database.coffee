async = require 'async'
USE_MONGO = process.env.USE_MONGO == 'true'

console.log "================================================"
console.log "  using #{if USE_MONGO then 'mongo' else 'nedb'}"
console.log "================================================"

if USE_MONGO
  mongojs = require 'mongojs'
  MONGO_DATABASE = mongojs 'meshblu-test', ['devices', 'subscriptions']

class TestDatabase
  @createNedbCollection: (collection, callback=->) =>
    Datastore = require 'nedb'
    datastore = new Datastore
      inMemoryOnly: true
      autoload: true
      onload: => callback null, datastore

  @open: (callback=->) =>
    if USE_MONGO
      async.parallel [
        (cb=->) => MONGO_DATABASE.devices.remove cb
        (cb=->) => MONGO_DATABASE.subscriptions.remove cb
      ], (error) => callback error, MONGO_DATABASE
    else
      async.parallel
        devices:       (cb=->) => @createNedbCollection 'devices', cb
        subscriptions: (cb=->) => @createNedbCollection 'subscriptions', cb
      , callback

module.exports = TestDatabase
