config = require '../config'

config.rateLimits ?= {};

tokenthrottle = require 'tokenthrottle'
if config.redis?.host
  redis = require './redis'
  tokenthrottle = require 'tokenthrottle-redis'
  redisClient = redis.client

module.exports =
  connection : tokenthrottle rate: config.rateLimits.connection, expiry: 1, redisClient
  message : tokenthrottle rate: config.rateLimits.message, expiry: 1, redisClient
  data : tokenthrottle rate: config.rateLimits.data, expiry: 1, redisClient
  query : tokenthrottle rate: config.rateLimits.query, expiry: 1, redisClient
  whoami : tokenthrottle rate: config.rateLimits.whoami, expiry: 1, redisClient
  unthrottledIps : config.rateLimits.unthrottledIps
