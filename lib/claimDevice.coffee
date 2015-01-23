_ = require 'lodash'

module.exports = (fromDevice, data, callback=_.noop, dependencies={}) ->
  return _.defer callback, new Error('failed to claim device') unless fromDevice?
  return _.defer callback, new Error('invalid device') unless data?

  updateDevice   = dependencies.updateDevice ? require './updateDevice'
  {canConfigure} = dependencies ? require './getSecurityImpl'

  return _.defer callback, new Error('not authorized to claim this device') unless canConfigure fromDevice, data

  updatedData = _.defaults {owner: fromDevice.uuid}, data, {discoverWhitelist: [fromDevice.uuid]}
  updateDevice data.uuid, updatedData, callback
