_ = require 'lodash'
path = require 'path'
debug = require('debug')('meshblu:integration:websocket')
MeshbluConfig = require 'meshblu-config'
MeshbluHTTP = require 'meshblu-http'
MeshbluWebsocket = require 'meshblu-websocket'
MeshbluSocketLogic = require 'meshblu'

describe 'SocketLogic Events', ->
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
        @eventForwarder.once 'message', (@message) =>
          done()

      it 'should send a "devices" message', ->
        expect(@message.topic).to.deep.equal 'devices'
        expect(@message.payload).to.deep.equal {
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
        expect(@message.payload).to.deep.equal {
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
        expect(@message.payload).to.deep.equal {
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
        expect(@message.payload).to.deep.equal {
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
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          request: {uuid: @device.uuid}
        }

  xdescribe 'EVENT update', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.update uuid: @device.uuid, foo: 'bar', (data) =>
          return done new Error(data.error) if data.error?
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "update" message', ->
        expect(@message.topic).to.deep.equal 'update'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          request:
            query: {uuid: @device.uuid}
            params: {$set: {foo: 'bar', uuid: @device.uuid}}
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.update uuid: 'invalid-uuid', foo: 'bar', (error) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send an "update-error" message', ->
        expect(@message.topic).to.deep.equal 'update-error'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          error: "Device not found"
          request:
            query: {uuid: 'invalid-uuid'}
            params: {$set: {foo: 'bar', uuid: 'invalid-uuid'}}
        }

  xdescribe 'EVENT localdevices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.localdevices (error) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "localdevices" message', ->
        expect(@message.topic).to.deep.equal 'localdevices'
        expect(@message.payload).to.deep.equal {
          fromIp: '127.0.0.1'
          fromUuid: @device.uuid
          request: {}
        }

  xdescribe 'EVENT unclaimeddevices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.unclaimeddevices {}, (error) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "unclaimeddevices" message', ->
        expect(@message.topic).to.deep.equal 'unclaimeddevices'
        expect(@message.payload).to.deep.equal {
          fromIp: '127.0.0.1'
          fromUuid: @device.uuid
          request: {}
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.unclaimeddevices {uuid: 'invalid-uuid'}, (error) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send an "unclaimeddevices-error" message', ->
        expect(@message.topic).to.deep.equal 'unclaimeddevices-error'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          fromIp: "127.0.0.1"
          error: "Devices not found"
          request:
            uuid: 'invalid-uuid'
        }

  xdescribe 'EVENT claimdevice', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register configWhitelist: ['*'], (data) =>
          return done new Error data.error if data.error?

          @newDevice = data
          @meshblu.claimdevice uuid: @newDevice.uuid, (data) =>
            return done new Error data.error if data.error?
            @eventForwarder.once 'message', (@message) =>
              done()

      it 'should send a "claimdevice" message', ->
        expect(@message.topic).to.deep.equal 'claimdevice'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          fromIp:   "127.0.0.1"
          request:
            uuid: @newDevice.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.claimdevice uuid: 'invalid-uuid', (data) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send an "claimdevice-error" message', ->
        expect(@message.topic).to.deep.equal 'claimdevice-error'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          fromIp:   '127.0.0.1'
          error:    'Device not found'
          request:
            uuid: 'invalid-uuid'
        }

  xdescribe 'EVENT getPublicKey', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.getPublicKey @config.uuid, (error) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "getpublickey" message', ->
        expect(@message.topic).to.deep.equal 'getpublickey'
        expect(@message.payload).to.deep.equal {
          request:
            uuid: @config.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.getPublicKey 'invalid-uuid', (error) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send an "getpublickey-error" message', ->
        expect(@message.topic).to.deep.equal 'getpublickey-error'
        expect(@message.payload).to.deep.equal {
          error: 'Device not found'
          request:
            uuid: 'invalid-uuid'
        }

  xdescribe 'EVENT resetToken', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register configWhitelist: ['*'], (data) =>
          return done new Error data.error if data.error?

          @newDevice = data
          @meshblu.resetToken @newDevice.uuid, (data) =>
            return done new Error data.error if data.error?
            @eventForwarder.once 'message', (@message) =>
              done()

      it 'should send a "resettoken" message', ->
        expect(@message.topic).to.deep.equal 'resettoken'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          request:
            uuid: @newDevice.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.resetToken 'invalid-uuid', (error) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send an "resettoken-error" message', ->
        expect(@message.topic).to.deep.equal 'resettoken-error'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          error:    'invalid device'
          request:
            uuid: 'invalid-uuid'
        }

  xdescribe 'EVENT generateAndStoreToken', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register configWhitelist: ['*'], (data) =>
          return done new Error data.error if data.error?

          @newDevice = data
          @meshblu.generateAndStoreToken uuid: @newDevice.uuid, (data) =>
            return done new Error data.error if data.error?
            @eventForwarder.once 'message', (@message) =>
              done()

      it 'should send a "generatetoken" message', ->
        expect(@message.topic).to.deep.equal 'generatetoken'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          request:
            uuid: @newDevice.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.generateAndStoreToken uuid: 'invalid-uuid', (data) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send an "generatetoken-error" message', ->
        expect(@message.topic).to.deep.equal 'generatetoken-error'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          error:    'Device not found'
          request:
            uuid: 'invalid-uuid'
        }

  xdescribe 'EVENT revokeToken', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register configWhitelist: ['*'], (data) =>
          return done new Error data.error if data.error?

          @meshblu.generateAndStoreToken uuid: data.uuid, (device) =>
            @newDevice = device
            @meshblu.revokeToken @newDevice, =>
              @eventForwarder.once 'message', (@message) =>
                done()

      it 'should send a "revoketoken" message', ->
        expect(@message.topic).to.deep.equal 'revoketoken'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          request:
            uuid: @newDevice.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.revokeToken uuid: 'invalid-uuid', token: 'invalid-token', (error) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send an "revoketoken-error" message', ->
        expect(@message.topic).to.deep.equal 'revoketoken-error'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          error:    'Device not found'
          request:
            uuid: 'invalid-uuid'
        }

  xdescribe 'EVENT register', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register {}, (data) =>
          return done new Error data.error if data.error?

          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "register" message', ->
        expect(@message.topic).to.deep.equal 'register'
        expect(@message.payload).to.deep.equal {
          request:
            ipAddress: '127.0.0.1'
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.register uuid: 'not-allowed', (error) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send an "register-error" message', ->
        expect(@message.topic).to.deep.equal 'register-error'
        expect(@message.payload).to.deep.equal {
          error:  'Device not updated'
          request:
            uuid: 'not-allowed'
            ipAddress: '127.0.0.1'
        }

  xdescribe 'EVENT unregister', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register {}, (data) =>
          return done new Error data.error if data.error?

          @newDevice = data
          @meshblu.unregister uuid: @newDevice.uuid, (data) =>
            return done new Error data.error if data.error?
            @eventForwarder.once 'message', (@message) =>
              done()

      it 'should send a "unregister" message', ->
        expect(@message.topic).to.deep.equal 'unregister'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          request: {uuid: @newDevice.uuid}
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.unregister uuid: 'invalid-uuid', (error) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send an "unregister-error" message', ->
        expect(@message.topic).to.deep.equal 'unregister-error'
        expect(@message.payload).to.deep.equal {
          error:  'invalid device to unregister'
          fromUuid: @device.uuid
          request: {uuid: 'invalid-uuid'}
        }

  xdescribe 'EVENT mydevices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register owner: @device.uuid, =>
          @meshblu.mydevices {}, =>
            @eventForwarder.once 'message', (@message) =>
              done()

      it 'should send a "devices" message', ->
        expect(@message.topic).to.deep.equal 'devices'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          request:
            owner: @device.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.mydevices {uuid: 'invalid-uuid'}, =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "devices-error" message', ->
        expect(@message.topic).to.deep.equal 'devices-error'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          error: "Devices not found"
          request:
            owner: @device.uuid
            uuid: 'invalid-uuid'
        }

  xdescribe 'EVENT subscribe', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.subscribe {uuid: @device.uuid}, (data) =>
          return done new Error data.error if data.error?

          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "subscribe" message', ->
        expect(@message.topic).to.deep.equal 'subscribe'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          request:
            uuid: @device.uuid
        }

    describe 'when called with a valid request with token', ->
      beforeEach (done) ->
        @meshblu.subscribe {uuid: @device.uuid, token: @device.token}, (data) =>
          return done new Error data.error if data.error?

          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "subscribe" message', ->
        expect(@message.topic).to.deep.equal 'subscribe'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          request:
            uuid: @device.uuid
        }

  xdescribe 'EVENT identity', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.identify()
        @eventForwarder.once 'message', (@message) =>
          done()

      it 'should send a "identity" message', ->
        expect(@message.topic).to.deep.equal 'identity'
        expect(@message.payload).to.deep.equal {
          request:
            uuid: @device.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @tempMeshblu = meshblu.createConnection _.pick(@config, 'server', 'port')
        @tempMeshblu.once 'ready', (@newDevice) =>
          @eventForwarder.once 'message', (@message) =>
            done() # To ignore the first 'identity' message

      beforeEach (done) ->
        @tempMeshblu.bufferedSocketEmit 'identity', uuid: 'invalid-uuid', debug: true
        @eventForwarder.on 'message', (message) =>
          if message.topic == 'identity-error'
            @message = message
            @eventForwarder.removeAllListeners 'message'
            done()

      it 'should send a "identity-error" message', ->
        expect(@message.topic).to.deep.equal 'identity-error'
        expect(@message.payload).to.deep.equal {
          error: "Device not found or token not valid"
          request:
            uuid: 'invalid-uuid'
        }

  xdescribe 'EVENT message', ->
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
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          request:
            devices: ['some-uuid']
        }

  xdescribe 'EVENT data', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.data uuid: @device.uuid, value: 1, =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "data" message', ->
        expect(@message.topic).to.deep.equal 'data'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          request:
            uuid: @device.uuid
            value: 1
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.data uuid: 'invalid-uuid', value: 1, =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "data-error" message', ->
        expect(@message.topic).to.deep.equal 'data-error'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          error: "Device not found"
          request:
            uuid: 'invalid-uuid'
            value: 1
        }

  xdescribe 'EVENT getdata', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.getdata uuid: @device.uuid, token: @device.token, =>
        @eventForwarder.on 'message', (message) =>
          if message.topic == 'subscribe'
            @message = message
            @eventForwarder.removeAllListeners 'message'
            done()

      it 'should send a "subscribe" message', ->
        expect(@message.topic).to.deep.equal 'subscribe'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          request:
            type: 'data'
            uuid: @device.uuid
        }