debug = require('debug')('meshblu:SocketIOThrottle')

class SocketIOThrottle
  constructor: ->
    @queryThrottle = require('./getThrottles').query

  throttle: (socket, next=->) =>
    @queryThrottle.rateLimit socket.id, (error, isLimited) =>
      debug 'rateLimit', socket.id, isLimited

      return @errorAndClose socket, error if error?
      return @errorAndClose socket, new Error('request exceeds rate limit') if isLimited

      next()

  errorAndClose: (socket, error) =>
    socket.emit 'notReady',{error: {message: 'Rate Limit Exceeded', code: 429}}
    socket.disconnect(true)

module.exports = SocketIOThrottle
