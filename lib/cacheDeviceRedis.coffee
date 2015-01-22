_ = require 'lodash'
redis = require './redis'

cacheDevice = (device) ->
  if device
    redis.set "DEVICE_" + device.uuid, JSON.stringify(device), _.noop

module.exports = cacheDevice
