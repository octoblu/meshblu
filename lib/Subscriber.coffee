{EventEmitter2} = require 'eventemitter2'

class Subscriber extends EventEmitter2
  constructor: ({@namespace}, {@client}={}) ->
    {createClient} = require './redis'
    @client ?= createClient()

    @client.on 'message', (channel, message) =>
      @emit 'message', channel, JSON.parse message

  subscribe: (type, uuid, callback) =>
    channel = @_channel type, uuid
    @client.subscribe channel, callback

  unsubscribe: (type, uuid, callback) =>
    channel = @_channel type, uuid
    @client.unsubscribe channel, callback

  _channel: (type, uuid) =>
    "#{@namespace}:#{type}:#{uuid}"

module.exports = Subscriber
