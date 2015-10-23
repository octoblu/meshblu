{EventEmitter2} = require 'eventemitter2'
{createClient}  = require './redis'

class Subscriber extends EventEmitter2
  constructor: ({@namespace}) ->
    @client = createClient()

    @client.on 'message', (channel, message) =>
      @emit 'message', channel, JSON.parse message

  close: =>
    @client.quit()

  subscribe: (type, uuid, callback) =>
    channel = @_channel type, uuid
    @client.subscribe channel, callback

  unsubscribe: (type, uuid, callback) =>
    channel = @_channel type, uuid
    @client.unsubscribe channel, callback

  _channel: (type, uuid) =>
    "#{@namespace}:#{type}:#{uuid}"

module.exports = Subscriber
