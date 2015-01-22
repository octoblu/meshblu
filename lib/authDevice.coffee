_ = require 'lodash'
bcrypt = require 'bcrypt'

module.exports = (uuid, token, callback=(->), database=null) ->
  database ?= require './database'
  devices = database.devices

  devices.findOne uuid: uuid, (error, device)->
    if device? && bcrypt.compareSync token, device.token
      delete device.token
      return callback null, device

    callback error, null

