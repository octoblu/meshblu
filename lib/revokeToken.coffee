_ = require 'lodash'

revokeToken = (ownerDevice, targetUuid, targetToken, callback=_.noop, dependencies={}) =>
  Device = dependencies.Device ? require('./models/device')
  getDevice = dependencies.getDevice ? require('./getDevice')
  securityImpl = dependencies.securityImpl ? require('./getSecurityImpl')

  getDevice targetUuid, (error, targetDevice) =>
    return callback new Error(error.error.message) if error?

    securityImpl.canConfigure ownerDevice, targetDevice, (error, permission) =>
      return callback new Error 'unauthorized' unless permission

      device = new Device uuid: targetUuid

      device.revokeToken targetToken, (error) =>
        return callback error if error?
        callback null

module.exports = revokeToken
