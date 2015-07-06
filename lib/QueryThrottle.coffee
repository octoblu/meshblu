_ = require 'lodash'
debug = require('debug')('meshblu:QueryThrottle')
toobusy = require 'toobusy'

class QueryThrottle
  constructor: ->
    @queryThrottle = require('./getThrottles').query

  throttle: (id, onThrottleCallback=_.noop, next=_.noop) =>
    if toobusy()
      serverTooBusyError = new Error('Server Too Busy')
      serverTooBusyError.status = 508
      return onThrottleCallback serverTooBusyError

    @queryThrottle.rateLimit id, (error, isLimited) =>
      debug 'rateLimit', id, isLimited

      if error?
        error.status = 500
        return onThrottleCallback error

      if isLimited
        rateLimitError = new Error('Rate Limit Exceeded')
        rateLimitError.status = 429
        return onThrottleCallback rateLimitError

      next()

module.exports = QueryThrottle
