resetToken  = (fromDevice, uuid, emitToClient, callback=(->), {securityImpl, getDevice, Device}={}) ->
  securityImpl ?= require './getSecurityImpl'
  getDevice ?= require './getDevice'
  Device ?= require './models/device'

  getDevice uuid, (error, gotDevice) ->
    return callback 'invalid device' if error?

    securityImpl.canConfigure fromDevice, gotDevice, (error, permission) =>
      return callback "unauthorized" unless permission

      device = new Device uuid: uuid
      device.resetToken (error, token) =>
        return callback "error updating device" if error?
        emitToClient 'notReady', fromDevice, {}
        return callback null, token

module.exports = resetToken
