config = require '../config'
debug = require('debug')('meshblu:message-io')

class MessageIO
  constructor: (dependencies={})->
    @SocketIO = dependencies.SocketIO ? require 'socket.io'
    @MessageIOSocketHandler = dependencies.MessageIOSocketHandler ? require './MessageIOSocketHandler'

  start: =>
    @io = @SocketIO config.messageBus.port

    @io.on 'connection', @onConnection

  setAdapter: (adapter) =>
    @io.adapter adapter

  onConnection: (socket) =>
    debug 'new connection', socket.id
    socketHandler = new @MessageIOSocketHandler
    socketHandler.initialize socket

module.exports = MessageIO
