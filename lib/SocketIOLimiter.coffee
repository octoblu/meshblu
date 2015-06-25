SocketIOThrottle = require './SocketIOThrottle'

class Limiter
  constructor: (@socket) ->

  throttle: (@callback=->) =>
    @throttled

  throttled: =>
    originalArguments = arguments
    new SocketIOThrottle().throttle @socket, =>
      @callback.apply this, originalArguments

module.exports = Limiter
