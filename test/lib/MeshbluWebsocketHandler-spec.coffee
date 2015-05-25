MeshbluWebsocketHandler = require '../../lib/MeshbluWebsocketHandler'

describe 'MeshbluWebsocketHandler', ->
  beforeEach ->
    @sut = new MeshbluWebsocketHandler
    @socket = sinon.spy => @socket

  describe 'initialize', ->
    beforeEach ->
      @socket.on = sinon.spy()
      @sut.initialize @socket

    it 'should register message event', ->
      expect(@socket.on).to.have.been.calledWith 'message'

    it 'should register close event', ->
      expect(@socket.on).to.have.been.calledWith 'close'

  describe 'sendFrame', ->
    describe 'sending a string', ->
      beforeEach ->
        @socket.send = sinon.spy()
        @sut.socket = @socket
        @sut.sendFrame 'test'

      it 'should serialize data if it is an object', ->
        expect(@socket.send).to.have.been.calledWith JSON.stringify ['test', null]

    describe 'sending an object', ->
      beforeEach ->
        @socket.send = sinon.spy()
        @sut.socket = @socket
        @sut.sendFrame 'test', foo: 'bar'

      it 'should serialize data if it is an object', ->
        expect(@socket.send).to.have.been.calledWith JSON.stringify ['test', foo: 'bar']

  describe.only 'parseFrame', ->
    describe 'when null', ->
      beforeEach ->
        @sut.parseFrame null, (@error) =>

      it 'should return an error', ->
        expect(@error).to.exist

    describe 'when invalid string', ->
      beforeEach ->
        @sut.parseFrame 'blah', (@error) =>

      it 'should return an error', ->
        expect(@error).to.exist

    describe 'when valid frame', ->
      beforeEach ->
        @sut.parseFrame '["test", {"foo":"bar"}]', (@error, @type, @data) =>

      it 'should not return an error', ->
        expect(@error).not.to.exist

      it 'should return a type', ->
        expect(@type).to.equal 'test'

      it 'should return data', ->
        expect(@data).to.deep.equal foo: 'bar'

    describe 'when super frame', ->
      beforeEach ->
        @sut.parseFrame '["test", {"foo":"bar"}, {"bar":"foo"}]', (@error, @type, @data, @data2) =>

      it 'should not return an error', ->
        expect(@error).not.to.exist

      it 'should return a type', ->
        expect(@type).to.equal 'test'

      it 'should return data', ->
        expect(@data).to.deep.equal foo: 'bar'

      it 'should return data2', ->
        expect(@data2).to.deep.equal bar: 'foo'

  describe 'sendError', ->
    beforeEach ->
      @sut.sendFrame = sinon.spy()
      @sut.sendError 'bad error'

    it 'should create the message and call send', ->
      expect(@sut.sendFrame).to.have.been.calledWith 'error', message: 'bad error'
