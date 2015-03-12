_ = require 'lodash'
redis = require './redis'

clearCache = (uuid) ->
  if uuid
    redis.del redis.CACHE_KEY + uuid, _.noop

module.exports = clearCache
