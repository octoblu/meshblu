_       = require 'lodash'
mongojs = require 'mongojs'

class TestDatabase
  @open: (callback=->) =>
    db = mongojs 'meshblu-test', ['devices']
    db.devices.remove (error) =>
      callback error, db

module.exports = TestDatabase
