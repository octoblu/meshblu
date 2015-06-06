class MessageIOSocketHandler
  initialize: (@socket) =>
    @id = @socket.id

    @socket.on 'subscribe', @onSubscribe
    @socket.on 'unsubscribe', @onUnsubscribe

  onSubscribe: (data) =>
    @socket.join data

  onUnsubscribe: (data) =>
    @socket.leave data

module.exports = MessageIOSocketHandler
