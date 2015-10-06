debug = require('debug')('meshblu:LimitusThrottle')
Limitus = require 'limitus'
limiter = new Limitus()
WINDOW_RATE = 1000

class LimitusThrottle
  constructor: (@name, rate) ->
    debug 'constructor', @name, rate
    limiter.rule @name, max: rate, interval: WINDOW_RATE, mode: 'interval'

  rateLimit: (id="", callback=->) =>
    debug 'rateLimit', @name, id
    limiter.drop @name, id, callback

module.exports = LimitusThrottle
