config = require('./../config')
socketEmitter = require('./createSocketEmitter')()
devices = require('./database').devices
whoAmI = require('./whoAmI')
securityImpl = require('./getSecurityImpl')

module.exports = (fromDevice, unregisterUuid, unregisterToken, emitToClient, callback) ->
  if !fromDevice or !unregisterUuid
    return callback('invalid from or to device')

  whoAmI unregisterUuid, true, (toDevice) ->
    if toDevice.error
      return callback('invalid device to unregister')

    securityImpl.canConfigure fromDevice, toDevice, { token: unregisterToken }, (error, permission) ->
      if !permission or error
        return callback(
          message: 'unauthorized'
          code: 401)

      if emitToClient
        emitToClient 'unregistered', toDevice, toDevice
      else
        socketEmitter toDevice.uuid, 'unregistered', toDevice

      devices.remove { uuid: unregisterUuid }, (err, devicedata) ->
        if err or devicedata == 0
          callback
            'message': 'Device not found or token not valid'
            'code': 404
          return
        callback null, uuid: unregisterUuid
