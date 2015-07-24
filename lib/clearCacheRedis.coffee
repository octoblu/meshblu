_ = require 'lodash'
redis = require './redis'

clearCache = (uuid, callback=->) ->
  if uuid
    redis.del redis.CACHE_KEY + uuid, callback

module.exports = clearCache
