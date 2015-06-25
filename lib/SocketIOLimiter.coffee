SocketIOThrottle = require './SocketIOThrottle'

class Limiter
  constructor: (@socket) ->

  throttle: (callback=->) =>
    ->
      originalArguments = arguments
      new SocketIOThrottle().throttle @socket, =>
        callback.apply this, originalArguments

module.exports = Limiter
