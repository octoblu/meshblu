crypto = require 'crypto'

generateToken = ->
  crypto.createHash('sha1').update((new Date()).valueOf().toString() + Math.random().toString()).digest('hex');


resetToken  = (fromDevice, uuid, callback=(->), securityImpl, getDevice, updateDevice) ->
  securityImpl = require './getSecurityImpl' unless securityImpl?
  getDevice = require './getDevice' unless getDevice?
  updateDevice = require './updateDevice' unless updateDevice?
  
  getDevice uuid, (error, device)->    
    return callback 'invalid device' if error?

    return callback "unauthorized" unless securityImpl.canUpdate fromDevice, device            
    token = generateToken()  

    updateDevice device.uuid, token: token, (error, device) ->
      return callback "error updating device" if error?
      return callback token

module.exports = resetToken