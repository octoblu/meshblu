_ = require 'lodash'

module.exports = (fromDevice, data, callback=_.noop, dependencies={}) ->
  return _.defer callback, new Error('failed to claim device') unless fromDevice?
  return _.defer callback, new Error('invalid device') unless data?

  getDevice    = dependencies.getDevice ? require './getDevice'
  updateDevice = dependencies.updateDevice ? require './updateDevice'
  canConfigure = dependencies.canConfigure ? require('./getSecurityImpl').canConfigure

  getDevice data.uuid, (error, device) => # have to getDevice to verify the ip address
    data = _.defaults {ipAddress: device.ipAddress}, data
    return callback new Error('not authorized to claim this device') unless canConfigure fromDevice, data

    updatedData = _.defaults {owner: fromDevice.uuid}, data, {discoverWhitelist: [fromDevice.uuid]}
    updateDevice data.uuid, updatedData, callback
