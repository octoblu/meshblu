Datastore = require 'nedb'

class TestDatabase
  @open: (callback=->) =>
    datastore = new Datastore
      inMemoryOnly: true
      autoload: true
      onload: => callback null, {devices: datastore}

module.exports = TestDatabase
