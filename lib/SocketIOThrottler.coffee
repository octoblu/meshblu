debug = require('debug')('meshblu:SocketIOThrottler')
_ = require 'lodash'
QueryThrottle = require './QueryThrottle'

class SocketIOThrottler
  constructor: (@socket) ->

  throttle: (fn=->) => =>
    originalArguments = arguments

    onThrottle = =>
      debug 'onThrottle'
      callback = _.last originalArguments

      callback [{message: 'Rate Limit Exceeded', status: 429}] if _.isFunction callback

      @socket.emit 'notReady',{error: {message: 'Rate Limit Exceeded', status: 429}}
      @socket.disconnect(true)

    new QueryThrottle().throttle @socket.id, onThrottle, =>
      fn.apply this, originalArguments

module.exports = SocketIOThrottler
