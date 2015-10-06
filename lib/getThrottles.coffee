debug = require('debug')('meshblu:getThrottles')

config = require '../config'

Throttle = require './LimitusThrottle'

config.rateLimits ?= {}

module.exports =
  connection: new Throttle 'connection', config.rateLimits.connection
  query     : new Throttle 'query',      config.rateLimits.query
  message   : new Throttle 'message',    config.rateLimits.message
  data      : new Throttle 'data',       config.rateLimits.data
  whoami:     new Throttle 'whoami',     config.rateLimits.whoami
  unthrottledIps : config.rateLimits.unthrottledIps
