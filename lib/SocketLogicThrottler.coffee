_ = require 'lodash'
debug = require('debug')('meshblu:SocketLogicThrottler')
QueryThrottle = require './QueryThrottle'

class SocketLogicThrottler
  constructor: (@socket) ->

  onThrottle: (error) =>
    debug 'onThrottle', 'notReady'
    @socket.emit 'notReady', {error: {message: error.message, code: error.status}}
    @socket.disconnect(true)

  throttle: (callback=->) => => # Not a typo, returning a curried function
    originalArguments = arguments
    new QueryThrottle().throttle @socket.id, @onThrottle, =>
      callback.apply this, originalArguments

module.exports = SocketLogicThrottler
