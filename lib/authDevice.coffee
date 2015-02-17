_      = require 'lodash'
async  = require 'async'
bcrypt = require 'bcrypt'
debug  = require('debug')('meshblu:authDevice')


module.exports = (uuid, token, callback=(->), database=null) ->
  database ?= require './database'
  devices = database.devices

  devices.findOne uuid: uuid, (error, device) =>
    return callback error, null unless device?

    hashedTokens = _.pluck(device.tokens, 'hash') ? []
    hashedTokens.push device.token if device.token?

    delete device.token

    compareToken = (hashedToken, next=->) =>
      debug token, hashedToken
      bcrypt.compare token, hashedToken, (@error, result) =>
        return callback @error if @error?
        return callback null, device if result
        next()

    async.eachSeries hashedTokens, compareToken, =>
      return callback null, null

