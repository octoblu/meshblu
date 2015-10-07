debug = require('debug')('meshblu:RedisThrottle')
moment = require 'moment'
redis = require './redis'
logError = require 'logError'

###
 THIS DOESN'T WORK YET!!
###

class RedisThrottle
  constructor: (@name, @rate) ->
    debug 'constructor', @name, @rate

  rateLimit: (id="", callback=->) =>
    key = "#{@name}:#{id}:#{moment().unix()}"
    debug 'rateLimit', callback

    redis.get key, (error, value) =>
      return if value > 10

      redis
        .multi()
        .incr(key, 1)
        .expire(key, 10)
        .exec (error) =>
          return logError error if error?
          callback()

module.exports = RedisThrottle

# FUNCTION LIMIT_API_CALL(ip)
# ts = CURRENT_UNIX_TIME()
# keyname = ip+":"+ts
# current = GET(keyname)
# IF current != NULL AND current > 10 THEN
#     ERROR "too many requests per second"
# ELSE
#     MULTI
#         INCR(keyname,1)
#         EXPIRE(keyname,10)
#     EXEC
#     PERFORM_API_CALL()
# END
