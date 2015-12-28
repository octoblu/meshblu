_ = require 'lodash'
path = require 'path'
meshblu = require 'meshblu'
MeshbluConfig = require 'meshblu-config'

describe 'SocketLogic Forwarder Events', ->
  before (done) ->
    filename = path.join __dirname, 'meshblu.json'
    @config = new MeshbluConfig(filename: filename).toJSON()
    @eventForwarder = meshblu.createConnection
      server : @config.server
      port   : @config.port
      uuid   : @config.uuid
      token  : @config.token

    @eventForwarder.on 'ready', => done()
    @eventForwarder.on 'notReady', done

  before (done) ->
    @meshblu = meshblu.createConnection _.pick(@config, 'server', 'port')
    @meshblu.once 'ready', (@device) => done()
    @meshblu.on 'notReady', done

  afterEach ->
    @eventForwarder.removeAllListeners()

  it 'should get here', ->
    expect(true).to.be.true

  describe 'EVENT devices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'devices'
        @meshblu.devices {}, (data) =>
          return done new Error(data.error) if data.error?

      it 'should send a "devices" message', ->
        expect(@message.topic).to.deep.equal 'devices'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request: {}
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'devices-error'
        @meshblu.devices {uuid: 'invalid-uuid'}, =>

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
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'devices'
        @meshblu.device {uuid: @device.uuid}, (data) =>
          return done new Error(data.error) if data.error?

      it 'should send a "devices" message', ->
        expect(@message.topic).to.deep.equal 'devices'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request:
            uuid: @device.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'devices-error'

        @meshblu.device {uuid: 'invalid-uuid'}, (data) =>

      it 'should send a "devices-error" message', ->
        expect(@message.topic).to.deep.equal 'devices-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          error: "Devices not found"
          request:
            uuid: 'invalid-uuid'
        }

  describe 'EVENT whoami', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'whoami'
        @meshblu.whoami {}, (data) =>
          return done new Error(data.error) if data.error?

      it 'should send a "whoami" message', ->
        expect(@message.topic).to.deep.equal 'whoami'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request: {}
        }

  describe 'EVENT update', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'update'

        @meshblu.update uuid: @device.uuid, foo: 'bar', (data) =>
          return done new Error(data.error) if data.error?

      it 'should send a "update" message', ->
        expect(@message.topic).to.deep.equal 'update'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request:
            query: {uuid: @device.uuid}
            params: {$set: {foo: 'bar', uuid: @device.uuid}}
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'update-error'
        @meshblu.update uuid: 'invalid-uuid', foo: 'bar', (error) =>

      it 'should send an "update-error" message', ->
        expect(@message.topic).to.deep.equal 'update-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          error: "Device not found"
          request:
            query: {uuid: 'invalid-uuid'}
            params: {$set: {foo: 'bar', uuid: 'invalid-uuid'}}
        }

  describe 'EVENT claimdevice', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'claimdevice'

        @meshblu.register configureWhitelist: ['*'], (data) =>
          return done new Error data.error if data.error?

          @newDevice = data
          @meshblu.claimdevice uuid: @newDevice.uuid, (data) =>
            return done new Error data.error if data.error?

      it 'should send a "claimdevice" message', ->
        expect(@message.topic).to.deep.equal 'claimdevice'
        expect(_.omit @message.payload, ['_timestamp', 'fromIp']).to.deep.equal {
          fromUuid: @device.uuid
          request:
            uuid: @newDevice.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'claimdevice-error'

        @meshblu.claimdevice uuid: 'invalid-uuid', (data) =>

      it 'should send an "claimdevice-error" message', ->
        expect(@message.topic).to.deep.equal 'claimdevice-error'
        expect(_.omit @message.payload, ['_timestamp', 'fromIp']).to.deep.equal {
          fromUuid: @device.uuid
          error:    'Device not found'
          request:
            uuid: 'invalid-uuid'
        }

  describe 'EVENT getPublicKey', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'getpublickey'

        @meshblu.getPublicKey @config.uuid, (error) =>

      it 'should send a "getpublickey" message', ->
        expect(@message.topic).to.deep.equal 'getpublickey'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          request:
            uuid: @config.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'getpublickey-error'
        @meshblu.getPublicKey 'invalid-uuid', (error) =>

      it 'should send an "getpublickey-error" message', ->
        expect(@message.topic).to.deep.equal 'getpublickey-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          error: 'Device not found'
          request:
            uuid: 'invalid-uuid'
        }

  describe 'EVENT resetToken', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'resettoken'
        @meshblu.register configureWhitelist: ['*'], (data) =>
          return done new Error data.error if data.error?

          @newDevice = data
          @meshblu.resetToken @newDevice.uuid, (data) =>
            return done new Error data.error if data.error?

      it 'should send a "resettoken" message', ->
        expect(@message.topic).to.deep.equal 'resettoken'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request:
            uuid: @newDevice.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'resettoken-error'

        @meshblu.resetToken 'invalid-uuid', (error) =>

      it 'should send an "resettoken-error" message', ->
        expect(@message.topic).to.deep.equal 'resettoken-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          error:    'invalid device'
          request:
            uuid: 'invalid-uuid'
        }

  describe 'EVENT generateAndStoreToken', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'generatetoken'
        @meshblu.register configureWhitelist: ['*'], (data) =>
          return done new Error data.error if data.error?

          @newDevice = data
          @meshblu.generateAndStoreToken uuid: @newDevice.uuid, (data) =>
            return done new Error data.error if data.error?

      it 'should send a "generatetoken" message', ->
        expect(@message.topic).to.deep.equal 'generatetoken'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request:
            uuid: @newDevice.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'generatetoken-error'

        @meshblu.generateAndStoreToken uuid: 'invalid-uuid', (data) =>

      it 'should send an "generatetoken-error" message', ->
        expect(@message.topic).to.deep.equal 'generatetoken-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          error:    'Device not found'
          request:
            uuid: 'invalid-uuid'
        }

  describe 'EVENT revokeToken', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'revoketoken'

        @meshblu.register configureWhitelist: ['*'], (data) =>
          return done new Error data.error if data.error?

          @meshblu.generateAndStoreToken uuid: data.uuid, (device) =>
            @newDevice = device
            @meshblu.revokeToken @newDevice, =>

      it 'should send a "revoketoken" message', ->
        expect(@message.topic).to.deep.equal 'revoketoken'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request:
            uuid: @newDevice.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'revoketoken-error'

        @meshblu.revokeToken uuid: 'invalid-uuid', token: 'invalid-token', (error) =>

      it 'should send an "revoketoken-error" message', ->
        expect(@message.topic).to.deep.equal 'revoketoken-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          error:    'Device not found'
          request:
            uuid: 'invalid-uuid'
        }

  describe 'EVENT register', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'register'

        @meshblu.register {}, (data) =>
          return done new Error data.error if data.error?

      it 'should send a "register" message', ->
        expect(@message.topic).to.deep.equal 'register'

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'register-error'
        @meshblu.register uuid: 'not-allowed', (error) =>

      it 'should send an "register-error" message', ->
        expect(@message.topic).to.deep.equal 'register-error'
        expect(@message.payload.error).to.equal 'Device not updated'

  describe 'EVENT unregister', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'unregister'
        @meshblu.register {}, (data) =>
          return done new Error data.error if data.error?

          @newDevice = data
          @meshblu.unregister uuid: @newDevice.uuid, (data) =>
            return done new Error data.error if data.error?

      it 'should send a "unregister" message', ->
        expect(@message.topic).to.deep.equal 'unregister'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request: {uuid: @newDevice.uuid}
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'unregister-error'

        @meshblu.unregister uuid: 'invalid-uuid', (error) =>

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
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'devices'

        @meshblu.register owner: @device.uuid, =>
          @meshblu.mydevices {}, =>

      it 'should send a "devices" message', ->
        expect(@message.topic).to.deep.equal 'devices'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request:
            owner: @device.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'devices-error'
        @meshblu.mydevices {uuid: 'invalid-uuid'}, =>

      it 'should send a "devices-error" message', ->
        expect(@message.topic).to.deep.equal 'devices-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          error: "Devices not found"
          request:
            owner: @device.uuid
            uuid: 'invalid-uuid'
        }

  describe 'EVENT subscribe', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'subscribe'

        @meshblu.subscribe {uuid: @device.uuid}, (data) =>
          return done new Error data.error if data.error?

      it 'should send a "subscribe" message', ->
        expect(@message.topic).to.deep.equal 'subscribe'
        expect(@message.payload.fromUuid).to.deep.equal @device.uuid
        expect(@message.payload.request.toUuid).to.deep.equal @device.uuid

    describe 'when called with a valid request with token', ->
      beforeEach (done) ->
        @eventForwarder.on 'message', (@message) =>
          done() if @message.topic == 'subscribe'

        @meshblu.subscribe {uuid: @device.uuid, token: @device.token}, (data) =>
          return done new Error data.error if data.error?

      it 'should send a "subscribe" message', ->
        expect(@message.topic).to.deep.equal 'subscribe'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request:
            uuid: @device.uuid
        }

  describe 'EVENT identity', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.identify()
        @eventForwarder.once 'message', (@message) =>
          done()

      it 'should send a "identity" message', ->
        expect(@message.topic).to.deep.equal 'identity'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
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
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          error: "Device not found or token not valid"
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

  describe 'EVENT data', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.data uuid: @device.uuid, value: 1, =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "data" message', ->
        expect(@message.topic).to.deep.equal 'data'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
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
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          error: "Device not found"
          request:
            uuid: 'invalid-uuid'
            value: 1
        }

  describe 'EVENT getdata', ->
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
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request:
            type: 'data'
            uuid: @device.uuid
        }
