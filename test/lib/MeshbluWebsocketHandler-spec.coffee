MeshbluWebsocketHandler = require '../../lib/MeshbluWebsocketHandler'

describe 'MeshbluWebsocketHandler', ->
  beforeEach ->
    @sut = new MeshbluWebsocketHandler
    @socket = sinon.spy => @socket

  describe 'initialize', ->
    beforeEach ->
      @socket.on = sinon.spy()
      @sut.addListener = sinon.spy()
      @sut.initialize @socket

    it 'should register message event', ->
      expect(@socket.on).to.have.been.calledWith 'message'

    it 'should register close event', ->
      expect(@socket.on).to.have.been.calledWith 'close'

    it 'should listen for status', ->
      expect(@sut.addListener).to.have.been.calledWith 'status'

    it 'should listen for identity', ->
      expect(@sut.addListener).to.have.been.calledWith 'identity'

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

  describe 'parseFrame', ->
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

  describe 'onMessage', ->
    beforeEach (done) ->
      @sut.addListener 'test', (@data) => done()
      @sut.onMessage data: '["test",{"far":"near"}]'

    it 'should emit test with object', ->
      expect(@data).to.deep.equal far: 'near'

  describe 'identity', ->
    describe 'when authDevice yields an error', ->
      beforeEach ->
        @authDevice = sinon.stub().yields new Error
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice
        @sut.sendFrame = sinon.stub()

        @sut.identity null

      it 'should emit notReady', ->
        expect(@sut.sendFrame).to.have.been.calledWith 'notReady', message: 'unauthorized', status: 401

    describe 'when authDevice yields a device', ->
      beforeEach ->
        @authDevice = sinon.stub().yields null, uuid: '1234'
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice
        @sut.sendFrame = sinon.stub()

        @sut.identity uuid: '1234', token: 'abcd'

      it 'should emit ready', ->
        expect(@sut.sendFrame).to.have.been.calledWith 'ready', uuid: '1234', token: 'abcd', status: 200

  describe 'status', ->
    beforeEach ->
      @getSystemStatus = sinon.stub().yields something: true
      @sut = new MeshbluWebsocketHandler getSystemStatus: @getSystemStatus
      @sut.sendFrame = sinon.stub()

      @sut.status()

    it 'should emit status', ->
      expect(@sut.sendFrame).to.have.been.calledWith 'status', something: true
