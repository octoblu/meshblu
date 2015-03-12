_ = require 'lodash'
redis = require './redis'

cacheDevice = (device) ->
  if device
    redis.setex redis.CACHE_KEY + device.uuid, redis.CACHE_TIMEOUT, JSON.stringify(device), _.noop

module.exports = cacheDevice
