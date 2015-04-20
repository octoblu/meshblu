_      = require 'lodash'
async  = require 'async'
bcrypt = require 'bcrypt'
debug  = require('debug')('meshblu:authDevice')


module.exports = (uuid, token, callback=(->), database=null) ->
  database ?= require './database'
  devices = database.devices

  devices.findOne uuid: uuid, (error, device) =>
    return callback new Error('Unable to find device') unless device?

    hashedTokens = _.pluck(device.tokens, 'hash') ? []
    hashedTokens.push device.token if device.token?

    delete device.token

    compareToken = (hashedToken, callback=->) =>
      debug token, hashedToken
      bcrypt.compare token, hashedToken, (error, result) =>
        callback(result)

    async.detect hashedTokens, compareToken, (goodToken)=>
      return callback(null, device) if goodToken?
      return callback null, null
