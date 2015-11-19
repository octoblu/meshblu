{EventEmitter2} = require 'eventemitter2'
{createClient}  = require './redis'

class Subscriber extends EventEmitter2
  constructor: ({@namespace}) ->
    @client = createClient()
    @client.on 'message', @_onMessage

  close: =>
    @client.end true

  subscribe: (type, uuid, callback) =>
    channel = @_channel type, uuid
    @client.subscribe channel, callback

  unsubscribe: (type, uuid, callback) =>
    channel = @_channel type, uuid
    @client.unsubscribe channel, callback

  _channel: (type, uuid) =>
    "#{@namespace}:#{type}:#{uuid}"

  _onMessage: (channel, messageStr) =>
    try
      message = JSON.parse messageStr
    catch
      return
    @emit 'message', channel, message

module.exports = Subscriber
