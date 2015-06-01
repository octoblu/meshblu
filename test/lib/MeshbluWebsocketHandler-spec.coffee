MeshbluWebsocketHandler = require '../../lib/MeshbluWebsocketHandler'

describe 'MeshbluWebsocketHandler', ->
  beforeEach ->
    @socketIOClient =
      on: sinon.spy()
      emit: sinon.spy()
    @SocketIOClient = sinon.spy => @socketIOClient
    @sut = new MeshbluWebsocketHandler SocketIOClient: @SocketIOClient
    @socket = sinon.spy => @socket

  describe 'initialize', ->
    beforeEach ->
      @socket.on = sinon.spy()
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

    it 'should create a SocketIO Client', ->
      expect(@SocketIOClient).to.have.been.calledWith 'ws://localhost:7777'

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
      expect(@sut.sendFrame).to.have.been.calledWith 'error', message: 'bad error', frame: undefined, code: undefined

  describe 'onMessage', ->
    describe 'when rateLimit exceeded', ->
      beforeEach ->
        @throttles = query: rateLimit: sinon.stub().yields new Error('rate limit exceeded')
        @sut = new MeshbluWebsocketHandler throttles: @throttles
        @sut.socket = id: '1555'
        @sut.sendError = sinon.spy()
        @sut.onMessage data: '["test",{"far":"near"}]'

      it 'should emit error', ->
        expect(@sut.sendError).to.have.been.calledWith 'rate limit exceeded', '["test",{"far":"near"}]', 429

    describe 'when rateLimit not exceeded', ->
      beforeEach (done) ->
        @throttles = query: rateLimit: sinon.stub().yields null, false
        @sut = new MeshbluWebsocketHandler throttles: @throttles
        @sut.socket = id: '1555'
        @sut.addListener 'test', (@data) => done()
        @sut.onMessage data: '["test",{"far":"near"}]'

      it 'should emit test with object', ->
        expect(@data).to.deep.equal far: 'near'

  describe 'identity', ->
    describe 'when authDevice yields an error', ->
      beforeEach ->
        @authDevice = sinon.stub().yields new Error
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice, SocketIOClient: @SocketIOClient
        @sut.sendFrame = sinon.stub()
        @sut.setOnlineStatus = sinon.spy()

        @sut.identity null

      it 'should emit notReady', ->
        expect(@sut.sendFrame).to.have.been.calledWith 'notReady', message: 'unauthorized', status: 401

    describe 'when authDevice yields a device', ->
      beforeEach ->
        @authDevice = sinon.stub().yields null, uuid: '1234'
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice, SocketIOClient: @SocketIOClient
        @sut.socketIOClient = @socketIOClient
        @sut.sendFrame = sinon.stub()
        @sut.setOnlineStatus = sinon.spy()

        @sut.identity uuid: '1234', token: 'abcd'

      it 'should emit ready', ->
        expect(@sut.sendFrame).to.have.been.calledWith 'ready', uuid: '1234', token: 'abcd', status: 200

      it 'should emit subscribe to my uuid', ->
        expect(@socketIOClient.emit).to.have.been.calledWith 'subscribe', '1234'

      it 'should emit subscribe to my uuid broadcast', ->
        expect(@socketIOClient.emit).to.have.been.calledWith 'subscribe', '1234_bc'

  describe 'status', ->
    beforeEach ->
      @getSystemStatus = sinon.stub().yields something: true
      @sut = new MeshbluWebsocketHandler getSystemStatus: @getSystemStatus
      @sut.sendFrame = sinon.stub()

      @sut.status()

    it 'should emit status', ->
      expect(@sut.sendFrame).to.have.been.calledWith 'status', something: true

  describe 'update', ->
    describe 'when authDevice yields an error', ->
      beforeEach ->
        @authDevice = sinon.stub().yields new Error
        @updateFromDevice = sinon.spy()
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice, updateFromDevice: @updateFromDevice
        @sut.sendError = sinon.spy()

        @sut.update uuid: '1345', online: true

      it 'should not call updateFromDevice', ->
        expect(@updateFromDevice).not.to.have.been.called

      it 'should call sendError', ->
        expect(@sut.sendError).to.have.been.called

    describe 'when authDevice yields a device', ->
      beforeEach ->
        @authDevice = sinon.stub().yields null, something: true
        @updateFromClient = sinon.spy()
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice, updateFromClient: @updateFromClient
        @sut.sendFrame = sinon.spy()

        @sut.update uuid: '1345', online: true

      it 'should emit update', ->
        expect(@updateFromClient).to.have.been.calledWith {something: true}, uuid: '1345', online: true

      it 'should send updated', ->
        expect(@sut.sendFrame).to.have.been.calledWith 'updated', uuid: '1345'

  describe 'subscribe', ->
    describe 'when authDevice yields an error', ->
      beforeEach ->
        @authDevice = sinon.stub().yields new Error
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice, SocketIOClient: @SocketIOClient
        @sut.sendError = sinon.spy()

        @sut.subscribe uuid: '1345', token: 'abcd'

      it 'should not call subscribe', ->
        expect(@socketIOClient.emit).not.to.have.been.called

      it 'should call sendError', ->
        expect(@sut.sendError).to.have.been.called

    describe 'when authDevice yields a device', ->
      beforeEach ->
        @authDevice = sinon.stub().yields null, something: true
        @getDevice = sinon.stub().yields null, uuid: '5431'
        @securityImpl = canReceive: sinon.stub().yields null, true
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice, SocketIOClient: @SocketIOClient, securityImpl: @securityImpl, getDevice: @getDevice
        @sut.socketIOClient = @socketIOClient
        @sut.sendFrame = sinon.spy()

        @sut.subscribe uuid: '5431'

      it 'should call subscribe _bc', ->
        expect(@socketIOClient.emit).to.have.been.calledWith 'subscribe', '5431_bc'

      it 'should not call subscribe on uuid', ->
        expect(@socketIOClient.emit).not.to.have.been.calledWith 'subscribe', '5431'

    describe 'when the device is owned by the owner', ->
      beforeEach ->
        @authDevice = sinon.stub().yields null, uuid: '1234'
        @getDevice = sinon.stub().yields null, uuid: '5431', owner: '1234'
        @securityImpl = canReceive: sinon.stub().yields null, true
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice, SocketIOClient: @SocketIOClient, securityImpl: @securityImpl, getDevice: @getDevice
        @sut.socketIOClient = @socketIOClient
        @sut.sendFrame = sinon.spy()

        @sut.subscribe uuid: '5431'

      it 'should call subscribe _bc', ->
        expect(@socketIOClient.emit).to.have.been.calledWith 'subscribe', '5431_bc'

      it 'should call subscribe on uuid', ->
        expect(@socketIOClient.emit).to.have.been.calledWith 'subscribe', '5431'

  describe 'unsubscribe', ->
    describe 'when authDevice yields an error', ->
      beforeEach ->
        @authDevice = sinon.stub().yields new Error
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice, SocketIOClient: @SocketIOClient
        @sut.socketIOClient = @socketIOClient
        @sut.sendError = sinon.spy()

        @sut.unsubscribe uuid: '1345', token: 'abcd'

      it 'should not call unsubscribe', ->
        expect(@socketIOClient.emit).not.to.have.been.called

      it 'should call sendError', ->
        expect(@sut.sendError).to.have.been.called

    describe 'when authDevice yields a device', ->
      beforeEach ->
        @authDevice = sinon.stub().yields null, something: true
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice, SocketIOClient: @SocketIOClient
        @sut.socketIOClient = @socketIOClient
        @sut.sendFrame = sinon.spy()

        @sut.unsubscribe uuid: '5431'

      it 'should call unsubscribe _bc', ->
        expect(@socketIOClient.emit).to.have.been.calledWith 'unsubscribe', '5431_bc'

      it 'should call unsubscribe on uuid', ->
        expect(@socketIOClient.emit).to.have.been.calledWith 'unsubscribe', '5431'

  describe 'message', ->
    describe 'when authDevice yields an error', ->
      beforeEach ->
        @authDevice = sinon.stub().yields new Error
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice, SocketIOClient: @SocketIOClient
        @sut.socketIOClient = @socketIOClient
        @sut.sendError = sinon.spy()

        @sut.message uuid: '1345', token: 'abcd'

      it 'should not call message', ->
        expect(@socketIOClient.emit).not.to.have.been.called

      it 'should call sendError', ->
        expect(@sut.sendError).to.have.been.called

    describe 'when authDevice yields a device', ->
      beforeEach ->
        @authDevice = sinon.stub().yields null, something: true
        @sendMessage = sinon.spy()
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice, SocketIOClient: @SocketIOClient, sendMessage: @sendMessage
        @sut.socketIOClient = @socketIOClient
        @sut.setOnlineStatus = sinon.spy()
        @sut.sendFrame = sinon.spy()

        @sut.message uuid: '5431'

      it 'should call message', ->
        expect(@sendMessage).to.have.been.calledWith {something: true}, uuid: '5431'

  describe 'device', ->
    describe 'when authDevice yields an error', ->
      beforeEach ->
        @authDevice = sinon.stub().yields new Error
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice
        @sut.socketIOClient = @socketIOClient
        @sut.sendError = sinon.spy()

        @sut.device uuid: '1345', token: 'abcd'

      it 'should not call device', ->
        expect(@socketIOClient.emit).not.to.have.been.called

      it 'should call sendError', ->
        expect(@sut.sendError).to.have.been.called

    describe 'when authDevice yields a device', ->
      beforeEach ->
        @authDevice = sinon.stub().yields null, something: true
        @getDevice = sinon.stub().yields null, uuid: '5431', online: true
        @securityImpl = canDiscover: sinon.stub().yields null, true
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice, getDevice: @getDevice, securityImpl: @securityImpl
        @sut.sendFrame = sinon.spy()

        @sut.device uuid: '5431'

      it 'should call device', ->
        expect(@sut.sendFrame).to.have.been.calledWith 'device', uuid: '5431', online: true

    describe 'when the uuid and token are given', ->
      beforeEach ->
        @authDevice = sinon.stub().yields null, uuid: '5431', online: true
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice
        @sut.sendFrame = sinon.spy()

        @sut.device uuid: '5431', token: '5999'

      it 'should call device', ->
        expect(@sut.sendFrame).to.have.been.calledWith 'device', uuid: '5431', online: true

  describe 'devices', ->
    describe 'when authDevice yields an error', ->
      beforeEach ->
        @authDevice = sinon.stub().yields new Error
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice
        @sut.socketIOClient = @socketIOClient
        @sut.sendError = sinon.spy()

        @sut.devices uuid: '1345', token: 'abcd'

      it 'should not call devices', ->
        expect(@socketIOClient.emit).not.to.have.been.called

      it 'should call sendError', ->
        expect(@sut.sendError).to.have.been.called

    describe 'when authDevice yields a devices', ->
      beforeEach ->
        @authDevice = sinon.stub().yields null, something: true
        @getDevices = sinon.stub().yields null, [{uuid: '5431', color: 'green'}, {uuid: '1234', color: 'green'}]
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice, getDevices: @getDevices
        @sut.sendFrame = sinon.spy()

        @sut.devices color: 'green'

      it 'should call devices', ->
        expect(@sut.sendFrame).to.have.been.calledWith 'devices', [{uuid: '5431', color: 'green'}, {uuid: '1234', color: 'green'}]

  describe 'mydevices', ->
    describe 'when authDevice yields an error', ->
      beforeEach ->
        @authDevice = sinon.stub().yields new Error
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice
        @sut.socketIOClient = @socketIOClient
        @sut.sendError = sinon.spy()

        @sut.mydevices color: 'green'

      it 'should not call devices', ->
        expect(@socketIOClient.emit).not.to.have.been.called

      it 'should call sendError', ->
        expect(@sut.sendError).to.have.been.called

    describe 'when authDevice yields a devices', ->
      beforeEach ->
        @authDevice = sinon.stub().yields null, uuid: '5555'
        @getDevices = sinon.stub().yields null, [{uuid: '5431', color: 'green', owner: '5555'}, {uuid: '1234', color: 'green', owner: '5555'}]
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice, getDevices: @getDevices
        @sut.sendFrame = sinon.spy()

        @sut.mydevices color: 'green'

      it 'should call devices', ->
        expect(@sut.sendFrame).to.have.been.calledWith 'mydevices', [{uuid: '5431', color: 'green', owner: '5555'}, {uuid: '1234', color: 'green', owner: '5555'}]

  describe 'whoami', ->
    describe 'when authDevice yields an error', ->
      beforeEach ->
        @authDevice = sinon.stub().yields new Error
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice
        @sut.socketIOClient = @socketIOClient
        @sut.sendError = sinon.spy()

        @sut.whoami()

      it 'should call sendError', ->
        expect(@sut.sendError).to.have.been.called

    describe 'when authDevice yields a devices', ->
      beforeEach ->
        @authDevice = sinon.stub().yields null, uuid: '5555'
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice
        @sut.sendFrame = sinon.spy()

        @sut.whoami()

      it 'should call devices', ->
        expect(@sut.sendFrame).to.have.been.calledWith 'whoami', uuid: '5555'

  describe 'register', ->
    describe 'when register yields an error', ->
      beforeEach ->
        @registerDevice = sinon.stub().yields new Error
        @sut = new MeshbluWebsocketHandler registerDevice: @registerDevice
        @sut.sendError = sinon.spy()

        @sut.register foo: 'bar'

      it 'should call sendError', ->
        expect(@sut.sendError).to.have.been.called

    describe 'when successful', ->
      beforeEach ->
        @registerDevice = sinon.stub().yields null, uuid: '5555', color: 'green'
        @sut = new MeshbluWebsocketHandler registerDevice: @registerDevice
        @sut.sendFrame = sinon.spy()

        @sut.register color: 'green'

      it 'should call register', ->
        expect(@sut.sendFrame).to.have.been.calledWith 'registered', uuid: '5555', color: 'green'

  describe 'unregister', ->
    describe 'when authDevice yields an error', ->
      beforeEach ->
        @authDevice = sinon.stub().yields new Error
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice
        @sut.sendError = sinon.spy()

        @sut.unregister uuid: '1345', online: true

      it 'should call sendError', ->
        expect(@sut.sendError).to.have.been.called

    describe 'when authDevice yields a device', ->
      beforeEach ->
        @authDevice = sinon.stub().yields null, something: true
        @unregisterDevice = sinon.spy()
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice, unregisterDevice: @unregisterDevice
        @sut.sendFrame = sinon.spy()

        @sut.unregister uuid: '1345'

      it 'should emit unregister', ->
        expect(@unregisterDevice).to.have.been.calledWith {something: true}, '1345'

      it 'should send unregistered', ->
        expect(@sut.sendFrame).to.have.been.calledWith 'unregistered', uuid: '1345'

    describe 'when the uuid and token are given', ->
      beforeEach ->
        @authDevice = sinon.stub().yields null, something: true
        @unregisterDevice = sinon.spy()
        @sut = new MeshbluWebsocketHandler authDevice: @authDevice, unregisterDevice: @unregisterDevice
        @sut.sendFrame = sinon.spy()

        @sut.unregister uuid: '5431', token: '5999'

      it 'should unregister', ->
        expect(@unregisterDevice).to.have.been.calledWith {something: true}, '5431'

      it 'should send unregistered', ->
        expect(@sut.sendFrame).to.have.been.calledWith 'unregistered', uuid: '5431'

  describe 'rateLimit', ->
    describe 'when limit function returns an error', ->
      beforeEach ->
        @throttles = query: rateLimit: sinon.stub().yields new Error
        @sut = new MeshbluWebsocketHandler throttles: @throttles

        @sut.rateLimit '1234', 'foo', (@error) =>

      it 'should yield an error', ->
        expect(@error).to.exist
