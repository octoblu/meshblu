_ = require 'lodash'
redis = require './redis'

clearCacheRedis = (uuid, callback=->) ->
  return callback() unless uuid?
  redis.del redis.CACHE_KEY + uuid
  callback()

module.exports = clearCacheRedis
