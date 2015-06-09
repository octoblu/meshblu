_ = require 'lodash'
config = require '../config'
debug = require('debug')('meshblu:MessageIOClient')
{EventEmitter} = require 'events'

class MessageIOClient extends EventEmitter
  constructor: (dependencies={}) ->
    @SocketIOClient = dependencies.SocketIOClient ? require 'socket.io-client'

  close: =>
    @socketIOClient.close()

  start: =>
    @socketIOClient = @SocketIOClient "ws://localhost:#{config.messageBus.port}", 'force new connection': true
    @socketIOClient.on 'message', (message) =>
      debug 'relay message', message
      @emit 'message', message

    @socketIOClient.on 'data', (message) =>
      debug 'relay message', message
      @emit 'data', message

    @socketIOClient.on 'config', (message) =>
      debug 'relay config', message
      @emit 'config', message

    @socketIOClient.connect()

  subscribe: (uuid, subscriptionTypes) =>
    if _.contains subscriptionTypes, 'received'
      debug 'subscribe', 'received', uuid
      @socketIOClient.emit 'subscribe', uuid

    if _.contains subscriptionTypes, 'broadcast'
      debug 'subscribe', 'broadcast', "#{uuid}_bc"
      @socketIOClient.emit 'subscribe', "#{uuid}_bc"

    if _.contains subscriptionTypes, 'sent'
      debug 'subscribe', 'sent', "#{uuid}_send"
      @socketIOClient.emit 'subscribe', "#{uuid}_send"

  unsubscribe: (uuid, subscriptionTypes) =>
    if _.contains subscriptionTypes, 'received'
      debug 'unsubscribe', 'received', uuid
      @socketIOClient.emit 'unsubscribe', uuid

    if _.contains subscriptionTypes, 'broadcast'
      debug 'unsubscribe', 'broadcast', "#{uuid}_bc"
      @socketIOClient.emit 'unsubscribe', "#{uuid}_bc"

    if _.contains subscriptionTypes, 'sent'
      debug 'unsubscribe', 'sent', "#{uuid}_send"
      @socketIOClient.emit 'unsubscribe', "#{uuid}_send"

module.exports = MessageIOClient
