_ = require 'lodash'
redis = require './redis'

clearCache = (uuid) ->
  if uuid
    redis.del "DEVICE_" + uuid, _.noop

module.exports = clearCache
