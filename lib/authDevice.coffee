_      = require 'lodash'
bcrypt = require 'bcrypt'

module.exports = (uuid, token, callback=(->), database=null) ->
  database ?= require './database'
  devices = database.devices

  devices.findOne uuid: uuid, (error, device) =>
    return callback error, null unless device?

    bcrypt.compare token, device.token, (error, result) =>
      return callback error, null if error?
      return callback null, null unless result

      delete device.token
      return callback null, device
