
class TestDatabase
  @open: (callback=->) =>
    if process.env.USE_MONGO == 'true'
      mongojs = require 'mongojs'
      db = mongojs 'meshblu-test', ['devices']
      db.devices.remove (error) =>
        callback error, db
    else
      Datastore = require 'nedb'
      datastore = new Datastore
        inMemoryOnly: true
        autoload: true
        onload: => callback null, {devices: datastore}


module.exports = TestDatabase
