_ = require 'lodash'

module.exports = (fromDevice, data, callback=_.noop, dependencies={}) ->
  return _.defer callback, new Error('failed to claim device') unless fromDevice?
  return _.defer callback, new Error('invalid device') unless data?

  getDeviceWithToken    = dependencies.getDeviceWithToken ? require './getDeviceWithToken'
  oldUpdateDevice = dependencies.oldUpdateDevice ? require './oldUpdateDevice'
  canConfigure = dependencies.canConfigure ? require('./getSecurityImpl').canConfigure

  getDeviceWithToken data.uuid, (error, device) => # have to getDevice to verify the ip address
    return callback new Error(error.error.message) if error?
    canConfigure fromDevice, device, (error, permission) =>
      return callback error if error?
      return callback new Error('not authorized to claim this device') unless permission

      if !_.isArray device.discoverWhitelist
        device.discoverWhitelist = []

      if !_.isArray device.configureWhitelist
        device.configureWhitelist = []

      device.discoverWhitelist.push fromDevice.uuid
      device.configureWhitelist.push fromDevice.uuid
      device.owner = fromDevice.uuid

      oldUpdateDevice data.uuid, device, callback
