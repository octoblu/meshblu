_ = require 'lodash'

generateAndStoreToken = (ownerDevice, message, callback=_.noop, dependencies={}) =>
  Device = dependencies.Device ? require('./models/device')
  getDevice = dependencies.getDevice ? require('./getDevice')
  securityImpl = dependencies.securityImpl ? require('./getSecurityImpl')
  {uuid, tag} = message

  getDevice uuid, (error, targetDevice) =>
    return callback new Error(error.error.message) if error?

    securityImpl.canConfigure ownerDevice, targetDevice, (error, permission) =>
      return callback new Error('unauthorized') unless permission

      device = new Device {uuid}
      token = device.generateToken()

      storeTokenOptions = {token}
      storeTokenOptions.tag = tag if tag?
      device.storeToken storeTokenOptions, (error) =>
        return callback error if error?
        callback null, storeTokenOptions

module.exports = generateAndStoreToken
