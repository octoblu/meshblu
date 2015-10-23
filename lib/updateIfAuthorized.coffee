_ = require 'lodash'

module.exports = (fromDevice, query, params, callback=_.noop, dependencies={}) ->
  securityImpl = dependencies.securityImpl ? require('./getSecurityImpl')
  Device = dependencies.Device ? require('./models/device')

  device = new Device uuid: query.uuid
  device.fetch (error, toDevice) =>
    securityImpl.canConfigure fromDevice, toDevice, query, (error, permission) =>
      return callback error if error?
      return callback new Error('Device does not have sufficient permissions for update') unless permission

      device.update params, (error) =>
        return callback error if error?
        callback()
