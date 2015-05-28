_      = require 'lodash'
async  = require 'async'
bcrypt = require 'bcrypt'
debug  = require('debug')('meshblu:authDevice')

module.exports = (uuid, token, callback=(->), dependencies={}) ->
  @getDeviceWithToken = dependencies.getDeviceWithToken ? require('./getDeviceWithToken')
  @getDeviceWithToken uuid, (error, device) =>
    debug 'gotDeviceWithToken', error, device
    return callback new Error('Unable to find valid device') unless device?

    hashedTokens = _.pluck(device.tokens, 'hash') ? []
    hashedTokens.push device.token if device.token?

    delete device.token

    compareToken = (hashedToken, callback=->) =>
      debug token, hashedToken
      bcrypt.compare token, hashedToken, (error, result) =>
        callback(result)

    # this is faster than async.detect, srsly, trust me.
    async.detectSeries hashedTokens.reverse(), compareToken, (goodToken) =>
      debug 'token matched?', goodToken?
      return callback null, device if goodToken?
      return callback new Error('Unable to find valid device')
