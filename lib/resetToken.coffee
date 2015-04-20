crypto = require 'crypto'

generateToken = ->
  crypto.createHash('sha1').update((new Date()).valueOf().toString() + Math.random().toString()).digest('hex');

resetToken  = (fromDevice, uuid, emitToClient, callback=(->), securityImpl, getDevice, updateDevice) ->
  securityImpl ?= require './getSecurityImpl'
  getDevice ?= require './getDevice'
  updateDevice ?= require './updateDevice'
  getDevice uuid, (error, device)->
    return callback 'invalid device' if error?

    securityImpl.canConfigure fromDevice, device, (error, permission) =>
      return callback "unauthorized" unless permission
      token = generateToken()

      updateDevice device.uuid, token: token, (error, device) ->
        return callback "error updating device" if error?
        emitToClient 'notReady', device, {}
        return callback null, token

module.exports = resetToken
