_ = require 'lodash'
path = require 'path'
meshblu = require 'meshblu'
MeshbluConfig = require 'meshblu-config'

describe 'SocketLogic Events', ->
  before ->
    filename = path.join __dirname, 'meshblu.json'
    @config = new MeshbluConfig(filename: filename).toJSON()

  before (done) ->
    @meshblu = meshblu.createConnection @config
    @meshblu.once 'ready', (@device) => done()
    @meshblu.on 'notReady', done

  afterEach ->
    @meshblu.removeAllListeners()

  it 'should get here', ->
    expect(true).to.be.true

  describe 'EVENT devices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.devices {}, (@data) =>
          return done new Error(@data.error) if @data.error?
          done()

      it 'should the correct data', ->
        expect(@data.devices).to.not.be.empty

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.devices {uuid: 'invalid-uuid'}, (@result) => done()

      it 'should have an error', ->
        expect(@result.error).to.exist

      it 'should not have a result', ->
        expect(@result.devices).to.not.exist

  describe 'EVENT device', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.device {uuid: @device.uuid}, (@data) =>
          return done new Error(@data.error) if @data.error?
          done()

      it 'should have a uuid', ->
        expect(@data.device.uuid).to.equal @device.uuid

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.device {uuid: 'invalid-uuid'}, (@result) => done()

      it 'should have an error', ->
        expect(@result.error.message).to.equal 'Devices not found'

  describe 'EVENT whoami', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.whoami {}, (@result) =>
          return done new Error(@result.error) if @result.error?
          done()

      it 'should have the correct uuid', ->
        expect(@result.uuid).to.equal @device.uuid

  describe 'EVENT update', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.update uuid: @device.uuid, foo: 'bar', (@result) =>
          return done new Error(@result.error) if @result.error?
          done()

      it 'should have return the updated device', ->
        expect(@result.uuid).to.exist

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.update uuid: 'invalid-uuid', foo: 'bar', (@result) => done()

      it 'should have a result.error', ->
        expect(@result.error.message).to.equal "Device not found"

  describe 'EVENT localdevices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.localdevices (@result) => done()

      it 'should not have an error', ->
        expect(@result.error).to.not.exist

      it 'should have a devices array', ->
        expect(@result.devices).to.be.an 'array'

  describe 'EVENT unclaimeddevices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register {}, =>
          @meshblu.unclaimeddevices {}, (@result) => done()

      it 'should not have an error', ->
        expect(@result.error).to.not.exist

      it 'should have a devices array', ->
        expect(@result.devices).to.be.an 'array'

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.unclaimeddevices {uuid: 'invalid-uuid'}, (@result) => done()

      it 'should have a result error', ->
        expect(@result.error).to.exist

  describe 'EVENT claimdevice', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register configWhitelist: ['*'], (data) =>
          return done new Error data.error if data.error?

          @newDevice = data
          @meshblu.claimdevice uuid: @newDevice.uuid, (@result) =>
            return done new Error data.error if data.error?
            done()

      it 'should have a result', ->
        expect(@result.results.uuid).to.deep.equal @newDevice.uuid

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.claimdevice uuid: 'invalid-uuid', (@result) => done()

      it 'should have a result error', ->
        expect(@result.error).to.deep.equal 'Device not found'

  describe 'EVENT getPublicKey', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.getPublicKey @config.uuid, (@error, @result) => done()

      it 'should not have a error', ->
        expect(@error).to.not.exist

      it 'should have a publicKey', ->
        expect(@result.isPublic()).to.deep.equal true

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.getPublicKey 'invalid-uuid', (@error, @result) => done()

      it 'should not have an error', ->
        expect(@error.message).to.equal 'Could not find public key for device'

  describe 'EVENT resetToken', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register configWhitelist: ['*'], (@newDevice) =>
          return done new Error @newDevice.error if @newDevice.error?
          @meshblu.resetToken @newDevice.uuid, (@result) =>
            return done new Error @result.error if @result.error?
            done()

      it 'should have the correct result', ->
        expect(@result.token).to.not.deep.equal @newDevice.token

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.resetToken 'invalid-uuid', (@result) => done()

      it 'should have an error', ->
        expect(@result.error).to.equal "invalid device"

  describe 'EVENT generateAndStoreToken', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register configWhitelist: ['*'], (data) =>
          return done new Error data.error if data.error?

          @newDevice = data
          @meshblu.generateAndStoreToken uuid: @newDevice.uuid, (@result) =>
            return done new Error @result.error if @result.error?
            done()

      it 'should have a different token', ->
        expect(@result.token).to.not.equal @newDevice.token

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.generateAndStoreToken uuid: 'invalid-uuid', (@result) => done()

      it 'should have an error', ->
        expect(@result.error).to.equal "Device not found"
        
  # describe 'EVENT revokeToken', ->
  #   describe 'when called with a valid request', ->
  #     beforeEach (done) ->
  #       @eventForwarder.on 'message', (@message) =>
  #         done() if @message.topic == 'revoketoken'
  #
  #       @meshblu.register configWhitelist: ['*'], (data) =>
  #         return done new Error data.error if data.error?
  #
  #         @meshblu.generateAndStoreToken uuid: data.uuid, (device) =>
  #           @newDevice = device
  #           @meshblu.revokeToken @newDevice, =>
  #
  #     it 'should send a "revoketoken" message', ->
  #       expect(@message.topic).to.deep.equal 'revoketoken'
  #       expect(_.omit @message.payload, '_timestamp').to.deep.equal {
  #         fromUuid: @device.uuid
  #         request:
  #           uuid: @newDevice.uuid
  #       }
  #
  #   describe 'when called with an invalid request', ->
  #     beforeEach (done) ->
  #       @eventForwarder.on 'message', (@message) =>
  #         done() if @message.topic == 'revoketoken-error'
  #
  #       @meshblu.revokeToken uuid: 'invalid-uuid', token: 'invalid-token', (error) =>
  #
  #     it 'should send an "revoketoken-error" message', ->
  #       expect(@message.topic).to.deep.equal 'revoketoken-error'
  #       expect(_.omit @message.payload, '_timestamp').to.deep.equal {
  #         fromUuid: @device.uuid
  #         error:    'Device not found'
  #         request:
  #           uuid: 'invalid-uuid'
  #       }
  #
  # describe 'EVENT register', ->
  #   describe 'when called with a valid request', ->
  #     beforeEach (done) ->
  #       @eventForwarder.on 'message', (@message) =>
  #         done() if @message.topic == 'register'
  #
  #       @meshblu.register {}, (data) =>
  #         return done new Error data.error if data.error?
  #
  #     it 'should send a "register" message', ->
  #       expect(@message.topic).to.deep.equal 'register'
  #       expect(_.omit @message.payload, '_timestamp').to.deep.equal {
  #         request:
  #           ipAddress: '127.0.0.1'
  #       }
  #
  #   describe 'when called with an invalid request', ->
  #     beforeEach (done) ->
  #       @eventForwarder.on 'message', (@message) =>
  #         done() if @message.topic == 'register-error'
  #       @meshblu.register uuid: 'not-allowed', (error) =>
  #
  #     it 'should send an "register-error" message', ->
  #       expect(@message.topic).to.deep.equal 'register-error'
  #       expect(_.omit @message.payload, '_timestamp').to.deep.equal {
  #         error:  'Device not updated'
  #         request:
  #           uuid: 'not-allowed'
  #           ipAddress: '127.0.0.1'
  #       }
  #
  # describe 'EVENT unregister', ->
  #   describe 'when called with a valid request', ->
  #     beforeEach (done) ->
  #       @eventForwarder.on 'message', (@message) =>
  #         done() if @message.topic == 'unregister'
  #       @meshblu.register {}, (data) =>
  #         return done new Error data.error if data.error?
  #
  #         @newDevice = data
  #         @meshblu.unregister uuid: @newDevice.uuid, (data) =>
  #           return done new Error data.error if data.error?
  #
  #     it 'should send a "unregister" message', ->
  #       expect(@message.topic).to.deep.equal 'unregister'
  #       expect(_.omit @message.payload, '_timestamp').to.deep.equal {
  #         fromUuid: @device.uuid
  #         request: {uuid: @newDevice.uuid}
  #       }
  #
  #   describe 'when called with an invalid request', ->
  #     beforeEach (done) ->
  #       @eventForwarder.on 'message', (@message) =>
  #         done() if @message.topic == 'unregister-error'
  #
  #       @meshblu.unregister uuid: 'invalid-uuid', (error) =>
  #
  #     it 'should send an "unregister-error" message', ->
  #       expect(@message.topic).to.deep.equal 'unregister-error'
  #       expect(_.omit @message.payload, '_timestamp').to.deep.equal {
  #         error:  'invalid device to unregister'
  #         fromUuid: @device.uuid
  #         request: {uuid: 'invalid-uuid'}
  #       }
  #
  # describe 'EVENT mydevices', ->
  #   describe 'when called with a valid request', ->
  #     beforeEach (done) ->
  #       @eventForwarder.on 'message', (@message) =>
  #         done() if @message.topic == 'devices'
  #
  #       @meshblu.register owner: @device.uuid, =>
  #         @meshblu.mydevices {}, =>
  #
  #     it 'should send a "devices" message', ->
  #       expect(@message.topic).to.deep.equal 'devices'
  #       expect(_.omit @message.payload, '_timestamp').to.deep.equal {
  #         fromUuid: @device.uuid
  #         request:
  #           owner: @device.uuid
  #       }
  #
  #   describe 'when called with an invalid request', ->
  #     beforeEach (done) ->
  #       @eventForwarder.on 'message', (@message) =>
  #         done() if @message.topic == 'devices-error'
  #       @meshblu.mydevices {uuid: 'invalid-uuid'}, =>
  #
  #     it 'should send a "devices-error" message', ->
  #       expect(@message.topic).to.deep.equal 'devices-error'
  #       expect(_.omit @message.payload, '_timestamp').to.deep.equal {
  #         fromUuid: @device.uuid
  #         error: "Devices not found"
  #         request:
  #           owner: @device.uuid
  #           uuid: 'invalid-uuid'
  #       }
  #
  # describe 'EVENT subscribe', ->
  #   describe 'when called with a valid request', ->
  #     beforeEach (done) ->
  #       @eventForwarder.on 'message', (@message) =>
  #         done() if @message.topic == 'subscribe'
  #
  #       @meshblu.subscribe {uuid: @device.uuid}, (data) =>
  #         return done new Error data.error if data.error?
  #
  #     it 'should send a "subscribe" message', ->
  #       expect(@message.topic).to.deep.equal 'subscribe'
  #       expect(@message.payload.fromUuid).to.deep.equal @device.uuid
  #       expect(@message.payload.request.toUuid).to.deep.equal @device.uuid
  #
  #   describe 'when called with a valid request with token', ->
  #     beforeEach (done) ->
  #       @eventForwarder.on 'message', (@message) =>
  #         done() if @message.topic == 'subscribe'
  #
  #       @meshblu.subscribe {uuid: @device.uuid, token: @device.token}, (data) =>
  #         return done new Error data.error if data.error?
  #
  #     it 'should send a "subscribe" message', ->
  #       expect(@message.topic).to.deep.equal 'subscribe'
  #       expect(_.omit @message.payload, '_timestamp').to.deep.equal {
  #         fromUuid: @device.uuid
  #         request:
  #           uuid: @device.uuid
  #       }
  #
  # describe 'EVENT identity', ->
  #   describe 'when called with a valid request', ->
  #     beforeEach (done) ->
  #       @meshblu.identify()
  #       @eventForwarder.once 'message', (@message) =>
  #         done()
  #
  #     it 'should send a "identity" message', ->
  #       expect(@message.topic).to.deep.equal 'identity'
  #       expect(_.omit @message.payload, '_timestamp').to.deep.equal {
  #         request:
  #           uuid: @device.uuid
  #       }
  #
  #   describe 'when called with an invalid request', ->
  #     beforeEach (done) ->
  #       @tempMeshblu = meshblu.createConnection _.pick(@config, 'server', 'port')
  #       @tempMeshblu.once 'ready', (@newDevice) =>
  #         @eventForwarder.once 'message', (@message) =>
  #           done() # To ignore the first 'identity' message
  #
  #     beforeEach (done) ->
  #       @tempMeshblu.bufferedSocketEmit 'identity', uuid: 'invalid-uuid', debug: true
  #       @eventForwarder.on 'message', (message) =>
  #         if message.topic == 'identity-error'
  #           @message = message
  #           @eventForwarder.removeAllListeners 'message'
  #           done()
  #
  #     it 'should send a "identity-error" message', ->
  #       expect(@message.topic).to.deep.equal 'identity-error'
  #       expect(_.omit @message.payload, '_timestamp').to.deep.equal {
  #         error: "Device not found or token not valid"
  #         request:
  #           uuid: 'invalid-uuid'
  #       }
  #
  # describe 'EVENT message', ->
  #   describe 'when called with a valid request', ->
  #     beforeEach (done) ->
  #       @meshblu.message {devices: ['some-uuid']}
  #       @eventForwarder.on 'message', (message) =>
  #         if message.topic == 'message'
  #           @message = message
  #           @eventForwarder.removeAllListeners 'message'
  #           done()
  #
  #     it 'should send a "message" message', ->
  #       expect(@message.topic).to.deep.equal 'message'
  #       expect(_.omit @message.payload, '_timestamp').to.deep.equal {
  #         fromUuid: @device.uuid
  #         request:
  #           devices: ['some-uuid']
  #       }
  #
  # describe 'EVENT data', ->
  #   describe 'when called with a valid request', ->
  #     beforeEach (done) ->
  #       @meshblu.data uuid: @device.uuid, value: 1, =>
  #         @eventForwarder.once 'message', (@message) =>
  #           done()
  #
  #     it 'should send a "data" message', ->
  #       expect(@message.topic).to.deep.equal 'data'
  #       expect(_.omit @message.payload, '_timestamp').to.deep.equal {
  #         fromUuid: @device.uuid
  #         request:
  #           uuid: @device.uuid
  #           value: 1
  #       }
  #
  #   describe 'when called with an invalid request', ->
  #     beforeEach (done) ->
  #       @meshblu.data uuid: 'invalid-uuid', value: 1, =>
  #         @eventForwarder.once 'message', (@message) =>
  #           done()
  #
  #     it 'should send a "data-error" message', ->
  #       expect(@message.topic).to.deep.equal 'data-error'
  #       expect(_.omit @message.payload, '_timestamp').to.deep.equal {
  #         fromUuid: @device.uuid
  #         error: "Device not found"
  #         request:
  #           uuid: 'invalid-uuid'
  #           value: 1
  #       }
  #
  # describe 'EVENT getdata', ->
  #   describe 'when called with a valid request', ->
  #     beforeEach (done) ->
  #       @meshblu.getdata uuid: @device.uuid, token: @device.token, =>
  #       @eventForwarder.on 'message', (message) =>
  #         if message.topic == 'subscribe'
  #           @message = message
  #           @eventForwarder.removeAllListeners 'message'
  #           done()
  #
  #     it 'should send a "subscribe" message', ->
  #       expect(@message.topic).to.deep.equal 'subscribe'
  #       expect(_.omit @message.payload, '_timestamp').to.deep.equal {
  #         fromUuid: @device.uuid
  #         request:
  #           type: 'data'
  #           uuid: @device.uuid
  #       }
