{EventEmitter} = require 'events'
MeshbluWebsocketHandler = require '../../lib/MeshbluWebsocketHandler'

describe 'MeshbluWebsocketHandler', ->
  beforeEach ->
    @messageIOClient =
      on: sinon.spy()
      emit: sinon.spy()
      unsubscribe: sinon.spy()
      start: sinon.spy()
      subscribe: sinon.spy()
    @MessageIOClient = sinon.spy => @messageIOClient
    @meshbluEventEmitter = new EventEmitter
    @meshbluEventEmitter.log = ->
    @sut = new MeshbluWebsocketHandler MessageIOClient: @MessageIOClient, meshbluEventEmitter: @meshbluEventEmitter
    @socket = sinon.spy => @socket

  describe 'initialize', ->
    beforeEach ->
      @socket.on = sinon.stub()
      @socket.on.withArgs('open').yields null
      @sut.addListener = sinon.spy()
      @sut.initialize @socket

    it 'should assign a socket.id', ->
      expect(@socket.id).to.exist

    it 'should register message event', ->
      expect(@socket.on).to.have.been.calledWith 'message'

    it 'should register close event', ->
      expect(@socket.on).to.have.been.calledWith 'close'

    it 'should listen for status', ->
      expect(@sut.addListener).to.have.been.calledWith 'status'

    it 'should listen for identity', ->
      expect(@sut.addListener).to.have.been.calledWith 'identity'

    it 'should listen for update', ->
      expect(@sut.addListener).to.have.been.calledWith 'update'

    it 'should listen for subscribe', ->
      expect(@sut.addListener).to.have.been.calledWith 'subscribe'

    it 'should listen for device', ->
      expect(@sut.addListener).to.have.been.calledWith 'device'

    it 'should listen for devices', ->
      expect(@sut.addListener).to.have.been.calledWith 'devices'

    it 'should listen for mydevices', ->
      expect(@sut.addListener).to.have.been.calledWith 'mydevices'

    it 'should listen for register', ->
      expect(@sut.addListener).to.have.been.calledWith 'register'

    it 'should listen for whoami', ->
      expect(@sut.addListener).to.have.been.calledWith 'whoami'

    it 'should create a MessageIO Client', ->
      expect(@MessageIOClient).to.have.been.calledWithNew

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
      expect(@sut.sendFrame).to.have.been.calledWith 'error', message: 'bad error', frame: undefined, status: undefined

  describe 'onMessage', ->
    describe 'when rateLimit exceeded', ->
      beforeEach ->
        @throttles = query: rateLimit: sinon.stub().yields new Error('rate limit exceeded')
        @sut = new MeshbluWebsocketHandler throttles: @throttles, meshbluEventEmitter: @meshbluEventEmitter
        @sut.socket = id: '1555', close: sinon.spy()
        @sut.sendError = sinon.spy()
        @sut.onMessage data: '["test",{"far":"near"}]'

      it 'should emit error', ->
        expect(@sut.sendError).to.have.been.calledWith 'rate limit exceeded', ["test",{"far":"near"}], 429

      it 'should close the socket', ->
        expect(@sut.socket.close).to.have.been.called

    describe 'when calling "identity"', ->
      beforeEach ->
        @throttles = query: rateLimit: sinon.stub().yields null, false
        @authDevice = sinon.spy()
        @sut = new MeshbluWebsocketHandler throttles: @throttles, authDevice: @authDevice, meshbluEventEmitter: @meshbluEventEmitter
        @sut.socket = id: '1555'
        sinon.spy @sut, 'emit'
        @sut.onMessage data: '["identity",{"uuid":"something", "token": "dah token"}]'

      it 'should not call authDevice', ->
        expect(@authDevice).to.have.not.been.called

      it 'should emit identity', ->
        expect(@sut.emit).to.have.been.calledWith 'identity', {uuid: 'something', token: 'dah token'}

    describe 'when calling "test" and rateLimit not exceeded', ->
      describe 'when authDevice yields an error', ->
        beforeEach (done) ->
          @throttles = query: rateLimit: sinon.stub().yields null, false
          @authDevice = sinon.stub().yields new Error
          @sut = new MeshbluWebsocketHandler throttles: @throttles, authDevice: @authDevice, meshbluEventEmitter: @meshbluEventEmitter
          @sut.socket = id: '1555'
          @sut.sendError = sinon.spy => done()
          sinon.spy @sut, 'emit'
          @sut.onMessage data: '["test",{"far":"near"}]'

        it 'should emit an error', ->
          expect(@sut.sendError).to.have.been.calledWith 'unauthorized', ["test",{"far":"near"}], 401

        it 'should not emit test', ->
          expect(@sut.emit).not.to.have.been.called

      describe 'when authDevice does not yields an error', ->
        beforeEach (done) ->
          @throttles = query: rateLimit: sinon.stub().yields null, false
          @authDevice = sinon.stub().yields null, {uuid: 'some-uuid', token: 'some-token'}
          @sut = new MeshbluWebsocketHandler throttles: @throttles, authDevice: @authDevice, meshbluEventEmitter: @meshbluEventEmitter
          @sut.uuid = 'some-uuid'
          @sut.token = 'some-token'
          @sut.socket = id: '1555'
          @sut.addListener 'test', (@data) => done()
          @sut.onMessage data: '["test",{"far":"near"}]'

        it 'should call authDevice', ->
          expect(@authDevice).to.have.been.calledWith 'some-uuid', 'some-token'

        it 'should emit test with object', ->
          expect(@data).to.deep.equal far: 'near'

        it 'should set @authedDevice', ->
          expect(@sut.authedDevice).to.deep.equal uuid: 'some-uuid', token: 'some-token'

  describe 'identity', ->
    describe 'when authDevice yields an error', ->
      beforeEach ->
        @authDevice = sinon.stub().yields new Error
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice, MessageIOClient: @MessageIOClient, meshbluEventEmitter: @meshbluEventEmitter
        @sut.sendFrame = sinon.stub()
        @sut.setOnlineStatus = sinon.spy()

        @sut.identity null

      it 'should emit notReady', ->
        expect(@sut.sendFrame).to.have.been.calledWith 'notReady', message: 'unauthorized', status: 401

    describe 'when authDevice yields a device', ->
      beforeEach ->
        @authDevice = sinon.stub().yields null, uuid: '1234'
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice, MessageIOClient: @MessageIOClient, meshbluEventEmitter: @meshbluEventEmitter
        @sut.messageIOClient = @messageIOClient
        @sut.sendFrame = sinon.stub()
        @sut.setOnlineStatus = sinon.spy()

        @sut.identity uuid: '1234', token: 'abcd'

      it 'should emit ready', ->
        expect(@sut.sendFrame).to.have.been.calledWith 'ready', uuid: '1234', token: 'abcd', status: 200

      it 'should emit subscribe to my uuid received and broadcast', ->
        expect(@messageIOClient.subscribe).to.have.been.calledWith '1234', ['received', 'config', 'data']

  describe 'status', ->
    beforeEach ->
      @getSystemStatus = sinon.stub().yields something: true
      @sut = new MeshbluWebsocketHandler getSystemStatus: @getSystemStatus, meshbluEventEmitter: @meshbluEventEmitter
      @sut.sendFrame = sinon.stub()

      @sut.status()

    it 'should emit status', ->
      expect(@sut.sendFrame).to.have.been.calledWith 'status', something: true

  describe 'update', ->
    describe 'when updateIfAuthorized yields an error', ->
      beforeEach ->
        @updateIfAuthorized = sinon.stub().yields new Error
        @sut = new MeshbluWebsocketHandler updateIfAuthorized: @updateIfAuthorized, meshbluEventEmitter: @meshbluEventEmitter
        @sut.authedDevice = {something: true}
        @sut.sendError = sinon.spy()

        @sut.update [{uuid: '1345'}, {$set: {online: true}}]

      it 'should call sendError', ->
        expect(@sut.sendError).to.have.been.called

    describe 'when updateIfAuthorized does not yield an error', ->
      beforeEach ->
        @updateIfAuthorized = sinon.stub().yields null
        @sut = new MeshbluWebsocketHandler updateIfAuthorized: @updateIfAuthorized, meshbluEventEmitter: @meshbluEventEmitter
        @sut.authedDevice = {something: true}
        @sut.sendFrame = sinon.spy()

        @sut.update [{uuid: '1345'}, {$set: {online: true}}]

      it 'should call updateIfAuthorized', ->
        expect(@updateIfAuthorized).to.have.been.calledWith {something: true}, {uuid: '1345'}, {$set: {online: true}}

      it 'should sendFrame with updated', ->
        expect(@sut.sendFrame).to.have.been.calledWith 'updated', uuid: '1345'

  describe 'subscribe', ->
    describe 'when authDevice yields a device', ->
      beforeEach ->
        @getDevice = sinon.stub().yields null, uuid: '5431'
        @securityImpl =
          canReceive: sinon.stub().yields null, true
          canReceiveAs: sinon.stub().yields null, false
        @sut = new MeshbluWebsocketHandler MessageIOClient: @MessageIOClient, securityImpl: @securityImpl, getDevice: @getDevice, meshbluEventEmitter: @meshbluEventEmitter
        @sut.messageIOClient = @messageIOClient
        @sut.authedDevice = something: true
        @sut.sendFrame = sinon.spy()

        @sut.subscribe uuid: '5431'

      it 'should call subscribe _bc', ->
        expect(@messageIOClient.subscribe).to.have.been.calledWith '5431', ["broadcast"]

      it 'should not call subscribe on uuid', ->
        expect(@messageIOClient.subscribe).not.to.have.been.calledWith '5431', ["received"]

    describe 'when the device is owned by the owner', ->
      beforeEach ->
        @getDevice = sinon.stub().yields null, uuid: '5431', owner: '1234'
        @securityImpl =
          canReceive: sinon.stub().yields null, true
          canReceiveAs: sinon.stub().yields null, true
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice, MessageIOClient: @MessageIOClient, securityImpl: @securityImpl, getDevice: @getDevice, meshbluEventEmitter: @meshbluEventEmitter
        @sut.authedDevice = uuid: '1234'
        @sut.messageIOClient = @messageIOClient
        @sut.sendFrame = sinon.spy()

        @sut.subscribe uuid: '5431'

      it 'should call subscribe _bc', ->
        expect(@messageIOClient.subscribe).to.have.been.calledWith '5431', ["broadcast", "received", "sent", "config", "data"]

  describe 'unsubscribe', ->
    describe 'when called', ->
      beforeEach ->
        @sut = new MeshbluWebsocketHandler MessageIOClient: @MessageIOClient, meshbluEventEmitter: @meshbluEventEmitter
        @sut.authedDevice = something: true
        @sut.messageIOClient = @messageIOClient
        @sut.sendFrame = sinon.spy()

        @sut.unsubscribe uuid: '5431'

      it 'should call unsubscribe with uuid', ->
        expect(@messageIOClient.unsubscribe).to.have.been.calledWith '5431', ['sent', 'received', 'broadcast']

  describe 'message', ->
    describe 'when authDevice yields a device', ->
      beforeEach ->
        @sendMessage = sinon.spy()
        @sut = new MeshbluWebsocketHandler MessageIOClient: @MessageIOClient, sendMessage: @sendMessage, meshbluEventEmitter: @meshbluEventEmitter
        @sut.authedDevice = something: true
        @sut.messageIOClient = @messageIOClient
        @sut.setOnlineStatus = sinon.spy()
        @sut.sendFrame = sinon.spy()

        @sut.message uuid: '5431'

      it 'should call message', ->
        expect(@sendMessage).to.have.been.calledWith {something: true}, uuid: '5431'

  describe 'device', ->
    describe 'when getDeviceIfAuthorized yields an error', ->
      beforeEach ->
        @getDeviceIfAuthorized = sinon.stub().yields new Error('unauthorized')
        @sut = new MeshbluWebsocketHandler getDeviceIfAuthorized: @getDeviceIfAuthorized, meshbluEventEmitter: @meshbluEventEmitter
        @sut.authedDevice = {}
        @sut.sendError = sinon.spy()

        @sut.device uuid: '5431'

      it 'should sendError with the error', ->
        expect(@sut.sendError).to.have.been.calledWith 'unauthorized', ["device", {"uuid": "5431"}]

    describe 'when the uuid and token are given', ->
      beforeEach ->
        @getDeviceIfAuthorized = sinon.stub().yields null, uuid: '5431', online: true
        @sut = new MeshbluWebsocketHandler getDeviceIfAuthorized: @getDeviceIfAuthorized, meshbluEventEmitter: @meshbluEventEmitter
        @sut.authedDevice = {}
        @sut.sendFrame = sinon.spy()

        @sut.device uuid: '5431', token: '5999'

      it 'should call sendFrame', ->
        expect(@sut.sendFrame).to.have.been.calledWith 'device', uuid: '5431', online: true

  describe 'devices', ->
    describe 'when getDevices yields devices', ->
      beforeEach ->
        @getDevices = sinon.stub().yields [{uuid: '5431', color: 'green'}, {uuid: '1234', color: 'green'}]
        @sut = new MeshbluWebsocketHandler getDevices: @getDevices, meshbluEventEmitter: @meshbluEventEmitter
        @sut.authedDevice = {}
        @sut.sendFrame = sinon.spy()
        @sut.devices color: 'green'

      it 'should call sendFrame with the devices', ->
        expect(@sut.sendFrame).to.have.been.calledWith 'devices', [{uuid: '5431', color: 'green'}, {uuid: '1234', color: 'green'}]

  describe 'mydevices', ->
    describe 'when called with a query', ->
      beforeEach ->
        @getDevices = sinon.stub().yields devices: [{uuid: '5431', color: 'green', owner: '5555'}, {uuid: '1234', color: 'green', owner: '5555'}]
        @sut = new MeshbluWebsocketHandler getDevices: @getDevices, meshbluEventEmitter: @meshbluEventEmitter
        @sut.sendFrame = sinon.spy()
        @sut.authedDevice = {}
        @sut.mydevices color: 'green'

      it 'should call devices', ->
        expect(@sut.sendFrame).to.have.been.calledWith 'mydevices', [{uuid: '5431', color: 'green', owner: '5555'}, {uuid: '1234', color: 'green', owner: '5555'}]

  describe 'whoami', ->
    describe 'when authDevice yields a devices', ->
      beforeEach ->
        @sut = new MeshbluWebsocketHandler meshbluEventEmitter: @meshbluEventEmitter
        @sut.authedDevice = uuid: '5555'
        @sut.sendFrame = sinon.spy()

        @sut.whoami()

      it 'should call devices', ->
        expect(@sut.sendFrame).to.have.been.calledWith 'whoami', uuid: '5555'

  describe 'register', ->
    describe 'when register yields an error', ->
      beforeEach ->
        @registerDevice = sinon.stub().yields new Error
        @sut = new MeshbluWebsocketHandler registerDevice: @registerDevice, meshbluEventEmitter: @meshbluEventEmitter
        @sut.sendError = sinon.spy()

        @sut.register foo: 'bar'

      it 'should call sendError', ->
        expect(@sut.sendError).to.have.been.called

    describe 'when successful', ->
      beforeEach ->
        @registerDevice = sinon.stub().yields null, uuid: '5555', color: 'green'
        @sut = new MeshbluWebsocketHandler registerDevice: @registerDevice, meshbluEventEmitter: @meshbluEventEmitter
        @sut.sendFrame = sinon.spy()

        @sut.register color: 'green'

      it 'should call register', ->
        expect(@sut.sendFrame).to.have.been.calledWith 'registered', uuid: '5555', color: 'green'

  describe 'unregister', ->
    describe 'when unregisterDevice yields nothing', ->
      beforeEach ->
        @unregisterDevice = sinon.stub().yields null
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice, unregisterDevice: @unregisterDevice, meshbluEventEmitter: @meshbluEventEmitter
        @sut.authedDevice = something: true
        @sut.sendFrame = sinon.spy()

        @sut.unregister uuid: '1345'

      it 'should emit unregister', ->
        expect(@unregisterDevice).to.have.been.calledWith {something: true}, '1345'

      it 'should send unregistered', ->
        expect(@sut.sendFrame).to.have.been.calledWith 'unregistered', uuid: '1345'

    describe 'when unregisterDevice yields an error', ->
      beforeEach ->
        @unregisterDevice = sinon.stub().yields 'this is not really an error object, but oh well'
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice, unregisterDevice: @unregisterDevice, meshbluEventEmitter: @meshbluEventEmitter
        @sut.authedDevice = something: true
        @sut.sendError = sinon.spy()

        @sut.unregister uuid: '5431'

      it 'should unregister', ->
        expect(@unregisterDevice).to.have.been.calledWith {something: true}, '5431'

      it 'should send an error', ->
        expect(@sut.sendError).to.have.been.calledWith 'this is not really an error object, but oh well', ['unregister', uuid: '5431']

  describe 'rateLimit', ->
    describe 'when limit function returns an error', ->
      beforeEach ->
        @throttles = query: rateLimit: sinon.stub().yields new Error
        @sut = new MeshbluWebsocketHandler throttles: @throttles, meshbluEventEmitter: @meshbluEventEmitter

        @sut.rateLimit '1234', 'foo', (@error) =>

      it 'should yield an error', ->
        expect(@error).to.exist
