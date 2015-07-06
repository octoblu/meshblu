_ = require 'lodash'
debug = require('debug')('meshblu:SocketLogicThrottler')
QueryThrottle = require './QueryThrottle'

class SocketLogicThrottler
  constructor: (@socket) ->

  onThrottle: =>
    debug 'onThrottle', 'notReady'
    @socket.emit 'notReady',{error: {message: 'Rate Limit Exceeded', code: 429}}
    @socket.disconnect(true)

  throttle: (callback=->) => => # Not a typo, returning a curried function
    originalArguments = arguments
    new QueryThrottle().throttle @socket.id, @onThrottle, =>
      callback.apply this, originalArguments

module.exports = SocketLogicThrottler
