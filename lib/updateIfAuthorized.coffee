_ = require 'lodash'

module.exports = (fromDevice, query, params, callback=_.noop, dependencies={}) ->
  securityImpl = dependencies.securityImpl ? require('./getSecurityImpl')
  getDevice = dependencies.getDevice ? require('./getDevice')
  Device = dependencies.Device ? require('./models/Device')

  getDevice query.uuid, (error, toDevice) =>
    securityImpl.canConfigure fromDevice, toDevice, query, (error, permission) =>
      return callback error if error?
      return callback new Error('Device does not have sufficient permissions for update') unless permission
      newDevice = new Device(uuid: toDevice.uuid)
      newDevice.update params, callback
