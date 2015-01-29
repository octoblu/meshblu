crypto = require 'crypto'

generateToken = ->
  crypto.createHash('sha1').update((new Date()).valueOf().toString() + Math.random().toString()).digest('hex');


resetToken  = (fromDevice, uuid, callback=(->), securityImpl, getDevice, updateDevice) ->
  securityImpl ?= require './getSecurityImpl'
  getDevice ?= require './getDevice'
  updateDevice ?= require './updateDevice'
  getDevice uuid, (error, device)->
    return callback 'invalid device' if error?

    return callback "unauthorized" unless securityImpl.canConfigure fromDevice, device            
    token = generateToken()  

    updateDevice device.uuid, token: token, (error, device) ->
      return callback "error updating device" if error?
      return callback null, token

module.exports = resetToken