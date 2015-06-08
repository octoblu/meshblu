config = require '../../config'
MessageIOClient = require '../../lib/messageIOClient'

describe 'MessageIOClient', ->
  beforeEach ->
    @socketIOClient =
      on: sinon.spy()
      connect: sinon.spy()
      close: sinon.spy()
      emit: sinon.spy()
    @FakeSocketIOClient = sinon.spy => @socketIOClient
    @sut = new MessageIOClient SocketIOClient: @FakeSocketIOClient

  describe 'extends EventEmitter', ->
    it 'should have emit', ->
      expect(@sut.emit).to.exist

  describe '.close', ->
    beforeEach ->
      @sut.start()
      @sut.close()

    it 'should call close on socketIOClient', ->
      expect(@socketIOClient.close).to.have.been.called

  describe '.start', ->
    beforeEach ->
      @sut.start()

    it 'should create a socketIOClient', ->
      expect(@FakeSocketIOClient).to.have.been.calledWith "ws://localhost:#{config.messageBus.port}", "force new connection": true

    it 'should call connect', ->
      expect(@socketIOClient.connect).to.have.been.called

    it 'should map message', ->
      expect(@socketIOClient.on).to.have.been.calledWith 'message'

    it 'should map data', ->
      expect(@socketIOClient.on).to.have.been.calledWith 'data'

    it 'should map config', ->
      expect(@socketIOClient.on).to.have.been.calledWith 'config'

  describe 'subscribe', ->
    describe 'received only', ->
      beforeEach ->
        @sut.start()
        @sut.subscribe 'apple', ['received']

      it 'should call emit on socketIOClient', ->
        expect(@socketIOClient.emit).to.have.been.calledWith 'subscribe', 'apple'

    describe 'sent only', ->
      beforeEach ->
        @sut.start()
        @sut.subscribe 'goeo', ['sent']

      it 'should call emit on socketIOClient', ->
        expect(@socketIOClient.emit).to.have.been.calledWith 'subscribe', 'goeo_send'

    describe 'broadcast only', ->
      beforeEach ->
        @sut.start()
        @sut.subscribe 'pear', ['broadcast']

      it 'should call emit on socketIOClient', ->
        expect(@socketIOClient.emit).to.have.been.calledWith 'subscribe', 'pear_bc'

    describe 'all kinds', ->
      beforeEach ->
        @sut.start()
        @sut.subscribe 'pear', ['broadcast', 'sent', 'received']

      it 'should call emit on socketIOClient', ->
        expect(@socketIOClient.emit).to.have.been.calledWith 'subscribe', 'pear'

      it 'should call emit on socketIOClient', ->
        expect(@socketIOClient.emit).to.have.been.calledWith 'subscribe', 'pear_send'

      it 'should call emit on socketIOClient', ->
        expect(@socketIOClient.emit).to.have.been.calledWith 'subscribe', 'pear_bc'

  describe 'unsubscribe', ->
    beforeEach ->
      @sut.start()
      @sut.unsubscribe 'apple'

    it 'should call emit on socketIOClient', ->
      expect(@socketIOClient.emit).to.have.been.calledWith 'unsubscribe', 'apple'
