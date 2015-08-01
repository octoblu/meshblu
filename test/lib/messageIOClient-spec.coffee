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

  describe 'topicMatch', ->
    describe 'by default', ->
      beforeEach ->
        @sut.start()
        @sut.subscribe 'apple', ['received']

      it 'should return true', ->
        expect(@sut.topicMatch('apple', 'pears')).to.be.true

      it 'should return true', ->
        expect(@sut.topicMatch('apple')).to.be.true

    describe 'when the topic is a string', ->
      beforeEach ->
        @sut.start()
        @sut.subscribe 'apple', ['received'], ['pears']

      describe 'when given the same string', ->
        it 'should return true', ->
          expect(@sut.topicMatch('apple', 'pears')).to.be.true

      describe 'when given a different string', ->
        it 'should return false', ->
          expect(@sut.topicMatch('apple', 'steak')).to.be.false

    describe 'when the topic ends in a wildcard', ->
      beforeEach ->
        @sut.start()
        @sut.subscribe 'apple', ['received'], ['pear*']

      describe 'when given the same string', ->
        it 'should return true', ->
          expect(@sut.topicMatch('apple', 'pear')).to.be.true

      describe 'when given one more character', ->
        it 'should return true', ->
          expect(@sut.topicMatch('apple', 'pears')).to.be.true

      describe 'when given a longer string', ->
        it 'should return true', ->
          expect(@sut.topicMatch('apple', 'pearson')).to.be.true

      describe 'when given a different string', ->
        it 'should return false', ->
          expect(@sut.topicMatch('apple', 'paer')).to.be.false

    describe 'when the topic starts and ends in a wildcard', ->
      beforeEach ->
        @sut.start()
        @sut.subscribe 'apple', ['received'], ['*ear*']

      describe 'when given the same string', ->
        it 'should return true', ->
          expect(@sut.topicMatch('apple', 'pear')).to.be.true

      describe 'when given one more character', ->
        it 'should return true', ->
          expect(@sut.topicMatch('apple', 'pears')).to.be.true

      describe 'when given a longer string', ->
        it 'should return true', ->
          expect(@sut.topicMatch('apple', 'pearson')).to.be.true

      describe 'when given a different string', ->
        it 'should return false', ->
          expect(@sut.topicMatch('apple', 'paer')).to.be.false

    describe 'when the topic contains a wildcard', ->
      beforeEach ->
        @sut.start()
        @sut.subscribe 'apple', ['received'], ['p*r']

      it 'should return true', ->
        expect(@sut.topicMatch('apple', 'pear')).to.be.true

      it 'should return true', ->
        expect(@sut.topicMatch('apple', 'paer')).to.be.true

      it 'should return false', ->
        expect(@sut.topicMatch('apple', 'raer')).to.be.false

    describe 'when the topic contains a minus', ->
      beforeEach ->
        @sut.start()
        @sut.subscribe 'apple', ['received'], ['-pears']

      it 'should return false', ->
        expect(@sut.topicMatch('apple', 'pears')).to.be.false

      it 'should return true', ->
        expect(@sut.topicMatch('apple', 'paer')).to.be.true

    describe 'when the topic contains a minus and a wildcard', ->
      beforeEach ->
        @sut.start()
        @sut.subscribe 'apple', ['received'], ['-p*r*']

      it 'should return false', ->
        expect(@sut.topicMatch('apple', 'pears')).to.be.false

      it 'should return false', ->
        expect(@sut.topicMatch('apple', 'paer')).to.be.false

      it 'should return true', ->
        expect(@sut.topicMatch('apple', 'dear')).to.be.true

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
        expect(@socketIOClient.emit).to.have.been.calledWith 'subscribe', 'goeo_sent'

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
        expect(@socketIOClient.emit).to.have.been.calledWith 'subscribe', 'pear_sent'

      it 'should call emit on socketIOClient', ->
        expect(@socketIOClient.emit).to.have.been.calledWith 'subscribe', 'pear_bc'

  describe 'unsubscribe', ->
    describe 'received only', ->
      beforeEach ->
        @sut.start()
        @sut.unsubscribe 'banana', ['received']

      it 'should call emit on socketIOClient', ->
        expect(@socketIOClient.emit).to.have.been.calledWith 'unsubscribe', 'banana'

    describe 'sent only', ->
      beforeEach ->
        @sut.start()
        @sut.unsubscribe 'watermelon', ['sent']

      it 'should call emit on socketIOClient', ->
        expect(@socketIOClient.emit).to.have.been.calledWith 'unsubscribe', 'watermelon_sent'

    describe 'broadcast only', ->
      beforeEach ->
        @sut.start()
        @sut.unsubscribe 'coffee', ['broadcast']

      it 'should call emit on socketIOClient', ->
        expect(@socketIOClient.emit).to.have.been.calledWith 'unsubscribe', 'coffee_bc'

    describe 'all kinds', ->
      beforeEach ->
        @sut.start()
        @sut.unsubscribe 'apple', ['broadcast', 'sent', 'received']

      it 'should call emit on socketIOClient', ->
        expect(@socketIOClient.emit).to.have.been.calledWith 'unsubscribe', 'apple'

      it 'should call emit on socketIOClient', ->
        expect(@socketIOClient.emit).to.have.been.calledWith 'unsubscribe', 'apple_sent'

      it 'should call emit on socketIOClient', ->
        expect(@socketIOClient.emit).to.have.been.calledWith 'unsubscribe', 'apple_bc'
