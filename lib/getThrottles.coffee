config = require '../config'

config.rateLimits ?= {};
windowRate = 60 * 1000

tokenthrottle = require 'tokenthrottle'
# if config.redis?.host
#   redis = require './redis'
#   tokenthrottle = require 'tokenthrottle-redis'
#   redisClient = redis.client

createThrottle = (rate) ->
  throttleConfig =
    window: windowRate
    rate: rate
    burst: rate * 2
  tokenthrottle throttleConfig #, redisClient

module.exports =
  connection : createThrottle config.rateLimits.connection
  message : createThrottle config.rateLimits.message
  data : createThrottle config.rateLimits.data
  query : createThrottle config.rateLimits.query
  whoami : createThrottle config.rateLimits.whoami
  unthrottledIps : config.rateLimits.unthrottledIps
