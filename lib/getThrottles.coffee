debug = require('debug')('meshblu:getThrottles')
Limitus = require 'limitus'
limiter = new Limitus()

config = require '../config'

config.rateLimits ?= {};
windowRate = 1000

createThrottle = (name, rate) ->
  debug 'createThrottle', name, rate
  limiter.rule name, max: rate, interval: windowRate
  rateLimit: (id="", callback=->) =>
    debug 'rateLimit', name, id
    limiter.drop(name, id, callback)

module.exports =
  connection: createThrottle 'connection', config.rateLimits.connection
  query:      createThrottle 'query', config.rateLimits.query
  message:    createThrottle 'message', config.rateLimits.message
  data:       createThrottle 'data', config.rateLimits.data
  whoami:     createThrottle 'whoami', config.rateLimits.whoami
  unthrottledIps : config.rateLimits.unthrottledIps
