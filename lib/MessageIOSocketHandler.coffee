_ = require 'lodash'
debug = require('debug')('meshblu:MessageIOSocketHandler')

class MessageIOSocketHandler
  initialize: (@socket) =>
    @id = @socket.id

    @socket.on 'subscribe', @onSubscribe
    @socket.on 'unsubscribe', @onUnsubscribe

  onSubscribe: (data) =>
    debug @socket.id, 'joining', data
    return if _.contains @socket.rooms, data
    @socket.join data

  onUnsubscribe: (data) =>
    debug @socket.id, 'leaving', data
    @socket.leave data

module.exports = MessageIOSocketHandler
