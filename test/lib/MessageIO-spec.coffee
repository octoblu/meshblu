MessageIO = require '../../lib/messageIO'
config = require '../../config'

describe 'MessageIO', ->
  beforeEach ->
    @socketIO = on: sinon.spy()
    @SocketIO = sinon.spy => @socketIO
    @sut = new MessageIO SocketIO: @SocketIO

  describe 'start', ->
    beforeEach ->
      @sut.start()

    it 'should initialize a socket.io connection', ->
      expect(@SocketIO).to.have.been.calledWith config.messageBus.port

    it 'should setup the onConnection handler', ->
      expect(@socketIO.on).to.have.been.calledWith 'connection'

  describe 'setAdapter', ->
    beforeEach ->
      @sut.io = @socketIO
      @socketIO.adapter = sinon.spy()
      @sut.setAdapter 'foo'

    it 'should call adapter on io', ->
      expect(@socketIO.adapter).to.have.been.calledWith 'foo'
