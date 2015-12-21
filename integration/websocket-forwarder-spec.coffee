_ = require 'lodash'
path = require 'path'
debug = require('debug')('meshblu:integration:websocket')
MeshbluConfig = require 'meshblu-config'
MeshbluHTTP = require 'meshblu-http'
MeshbluWebsocket = require 'meshblu-websocket'
MeshbluSocketLogic = require 'meshblu'

describe 'WebSocket Forwarder Events', ->
  before (done) ->
    filename = path.join __dirname, 'meshblu.json'
    @config = new MeshbluConfig(filename: filename).toJSON()

    @eventForwarder = new MeshbluWebsocket @config
    @eventForwarder.connect =>
      @eventForwarder.subscribe @config.uuid
      done()

  before (done) ->
    meshbluHTTP = new MeshbluHTTP _.pick @config, 'server', 'port'
    meshbluHTTP.register {}, (error, device) =>
      return done error if error?

      @device = device
      @meshblu = new MeshbluWebsocket uuid: @device.uuid, token: @device.token, host: @config.host, protocol: @config.protocol
      @meshblu.connect (error) =>
        done error
      @meshblu.on 'error', (error) =>
        debug '@meshblu error', error

  it 'should get here', ->
    expect(true).to.be.true

  describe 'EVENT devices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.devices {}
        @eventForwarder.on 'message', (message) =>
          if message.topic == 'devices'
            @message = message
            @eventForwarder.removeAllListeners 'message'
            done()

      it 'should send a "devices" message', ->
        expect(@message.topic).to.deep.equal 'devices'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request: {}
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.devices {uuid: 'invalid-uuid'}
        @eventForwarder.once 'message', (@message) =>
          done()

      it 'should send a "devices-error" message', ->
        expect(@message.topic).to.deep.equal 'devices-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          error: "Devices not found"
          request:
            uuid: 'invalid-uuid'
        }

  describe 'EVENT device', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.device @device.uuid
        @eventForwarder.once 'message', (@message) =>
          done()

      it 'should send a "devices" message', ->
        expect(@message.topic).to.deep.equal 'devices'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request:
            uuid: @device.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.device 'invalid-uuid'
        @eventForwarder.once 'message', (@message) =>
          done()

      it 'should send a "devices-error" message', ->
        expect(@message.topic).to.deep.equal 'devices-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          error: 'unauthorized'
          request:
            uuid: 'invalid-uuid'
        }

  describe 'EVENT whoami', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.whoami()
        @eventForwarder.once 'message', (@message) =>
          done()

      it 'should send a "whoami" message', ->
        expect(@message.topic).to.deep.equal 'devices'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request: {uuid: @device.uuid}
        }

  describe 'EVENT update', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.update {uuid: @device.uuid}, {foo: 'bar'}
        @eventForwarder.once 'message', (@message) =>
          done()

      it 'should send a "update" message', ->
        expect(@message.topic).to.deep.equal 'update'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request:
            query: {uuid: @device.uuid}
            params: {$set: {foo: 'bar'}}
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.update {uuid: 'invalid-uuid'}, {foo: 'bar'}
        @eventForwarder.once 'message', (@message) =>
          done()

      it 'should send an "update-error" message', ->
        expect(@message.topic).to.deep.equal 'update-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          error: "Device does not have sufficient permissions for update"
          request:
            query: {uuid: 'invalid-uuid'}
            params: {$set: {foo: 'bar'}}
        }

  describe 'EVENT register', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register {foo: 'bar'}
        @eventForwarder.once 'message', (@message) =>
          done()

      it 'should send a "register" message', ->
        expect(@message.topic).to.deep.equal 'register'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request: {foo: 'bar'}
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.register uuid: 'not-allowed'
        @eventForwarder.once 'message', (@message) =>
          done()

      it 'should send an "register-error" message', ->
        expect(@message.topic).to.deep.equal 'register-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          error:  'Device not updated'
          fromUuid: @device.uuid
          request:
            uuid: 'not-allowed'
        }

  describe 'EVENT unregister', ->
    describe 'when called with a valid request without token', ->
      beforeEach (done) ->
        @meshblu.register {configureWhitelist: [@device.uuid]}
        @meshblu.once 'registered', (data) =>
          @newDevice = data
          done()

      beforeEach (done) ->
        @meshblu.unregister uuid: @newDevice.uuid
        @eventForwarder.on 'message', (message) =>
          if message.topic == 'unregister'
            @message = message
            @eventForwarder.removeAllListeners 'message'
            done()

      it 'should send a "unregister" message', ->
        expect(@message.topic).to.deep.equal 'unregister'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request: {uuid: @newDevice.uuid}
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.unregister uuid: 'invalid-uuid'
        @eventForwarder.once 'message', (@message) =>
          done()

      it 'should send an "unregister-error" message', ->
        expect(@message.topic).to.deep.equal 'unregister-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          error:  'invalid device to unregister'
          fromUuid: @device.uuid
          request: {uuid: 'invalid-uuid'}
        }

  describe 'EVENT mydevices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register  owner: @device.uuid, discoverWhitelist: [@device.uuid]
        @meshblu.once 'registered', (data) =>
          @newDevice = data
          done()

      beforeEach (done) ->
        @meshblu.mydevices()
        @eventForwarder.on 'message', (message) =>
          if message.topic == 'devices'
            @message = message
            @eventForwarder.removeAllListeners 'message'
            done()

      it 'should send a "devices" message', ->
        expect(@message.topic).to.deep.equal 'devices'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request:
            owner: @device.uuid
        }

  describe 'EVENT subscribe', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.subscribe @device.uuid
        @eventForwarder.once 'message', (@message) =>
          done()

      it 'should send a "subscribe" message', ->
        expect(@message.topic).to.deep.equal 'subscribe'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request:
            uuid: @device.uuid
        }

  describe 'EVENT unsubscribe', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.unsubscribe @device.uuid
        @eventForwarder.once 'message', (@message) =>
          done()

      it 'should send a "unsubscribe" message', ->
        expect(@message.topic).to.deep.equal 'unsubscribe'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request:
            uuid: @device.uuid
        }

  describe 'EVENT identity', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.identity uuid: @device.uuid, token: @device.token
        @eventForwarder.once 'message', (@message) =>
          done()

      it 'should send a "identity" message', ->
        expect(@message.topic).to.deep.equal 'identity'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request:
            uuid: @device.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.register()
        @meshblu.on 'registered', (device) =>
          @newDevice = device
          done()

      beforeEach (done) ->
        @tempMeshblu = new MeshbluWebsocket uuid: @newDevice.uuid, token: @newDevice.token, host: @config.host, protocol: @config.protocol
        @tempMeshblu.connect (error) =>
          done error
        @tempMeshblu.on 'error', (error) =>
          debug '@tempMeshblu error', error

      beforeEach (done) ->
        @tempMeshblu.identity uuid: 'invalid-uuid', token: 'invalid-token'
        @eventForwarder.on 'message', (message) =>
          if message.topic == 'identity-error'
            @message = message
            @eventForwarder.removeAllListeners 'message'
            done()

      it 'should send a "identity-error" message', ->
        expect(@message.topic).to.deep.equal 'identity-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          error: "Invalid Device UUID"
          fromUuid: 'invalid-uuid'
          request:
            uuid: 'invalid-uuid'
        }

  describe 'EVENT message', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.message {devices: ['some-uuid']}
        @eventForwarder.on 'message', (message) =>
          if message.topic == 'message'
            @message = message
            @eventForwarder.removeAllListeners 'message'
            done()

      it 'should send a "message" message', ->
        expect(@message.topic).to.deep.equal 'message'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request:
            devices: ['some-uuid']
        }
