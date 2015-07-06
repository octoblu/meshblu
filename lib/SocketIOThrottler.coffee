debug = require('debug')('meshblu:SocketIOThrottler')
_ = require 'lodash'
QueryThrottle = require './QueryThrottle'

class SocketIOThrottler
  constructor: (@socket) ->

  throttle: (fn=->) => =>
    originalArguments = arguments

    onThrottle = (error) =>
      debug 'onThrottle'
      callback = _.last originalArguments

      callback [{message: error.message, status: error.status}] if _.isFunction callback

      @socket.emit 'notReady',{error: {message: error.message, status: error.status}}
      @socket.disconnect(true)

    new QueryThrottle().throttle @socket.id, onThrottle, =>
      fn.apply this, originalArguments

module.exports = SocketIOThrottler
