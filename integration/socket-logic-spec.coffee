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

  describe 'EVENT claimdevice', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register configureWhitelist: ['*'], (data) =>
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
        @meshblu.register configureWhitelist: ['*'], (@newDevice) =>
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
        @meshblu.register configureWhitelist: ['*'], (data) =>
          return done new Error data.error if data.error?

          @newDevice = data
          @meshblu.generateAndStoreToken uuid: @newDevice.uuid, (@result) =>
            return done new Error @result.error if @result.error?
            done()

      it 'should have a different token', ->
        expect(@result.token).to.not.equal @newDevice.token

    describe 'when called with a valid tag request', ->
      beforeEach (done) ->
        @meshblu.register configureWhitelist: ['*'], (data) =>
          return done new Error data.error if data.error?

          @newDevice = data
          @meshblu.generateAndStoreToken uuid: @newDevice.uuid, tag: 'some-tag', (@result) =>
            return done new Error @result.error if @result.error?
            done()

      it 'should have the correct result', ->
        expect(@result.token).to.not.equal @newDevice.token
        expect(@result.tag).to.equal 'some-tag'

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.generateAndStoreToken uuid: 'invalid-uuid', (@result) => done()

      it 'should have an error', ->
        expect(@result.error).to.equal "Device not found"

  describe 'EVENT revokeToken', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register configureWhitelist: ['*'], (data) =>
          return done new Error data.error if data.error?

          @meshblu.generateAndStoreToken uuid: data.uuid, (device) =>
            @newDevice = device
            @meshblu.revokeToken @newDevice, (@result)=>
              done()

      it 'should not have an error', ->
        expect(@result.error).to.not.exist

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.revokeToken uuid: 'invalid-uuid', token: 'invalid-token', (@result) => done()

      it 'should have an error', ->
        expect(@result.error).to.exist

  describe 'EVENT register', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register {}, (@result) =>
          return done new Error @result.error if @result.error?
          done()

      it 'should have a uuid', ->
        expect(@result.uuid).to.exist

      it 'should have a token', ->
        expect(@result.token).to.exist

      it 'should have online = false', ->
        expect(@result.online).to.be.false

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.register uuid: 'not-allowed', (@result) => done()

      it 'should have a result.error', ->
        expect(@result.error).to.exist

  describe 'EVENT unregister', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register {}, (data) =>
          return done new Error data.error if data.error?

          @newDevice = data
          @meshblu.unregister uuid: @newDevice.uuid, (@result) =>
            return done new Error data.error if data.error?
            done()

      it 'should have the correct result', ->
        expect(@result.fromUuid).to.equal @config.uuid
        expect(@result.from).to.exist

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.unregister uuid: 'invalid-uuid', (@result) => done()

      it 'should have a result.error', ->
        expect(@result.error).to.exist

  describe 'EVENT mydevices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register owner: @device.uuid, =>
          @meshblu.mydevices {}, (@result) => done()

      it 'should have the correct result', ->
        expect(@result.devices).to.not.be.empty
        expect(@result.devices).to.be.an 'array'

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.mydevices {uuid: 'invalid-uuid'}, (@result) => done()

      it 'should have empty devices', ->
        expect(@result.devices).to.be.empty

  describe 'EVENT subscribe', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.on 'message', (@message) =>
          done() if @message.topic == 'im-awesome'
        @meshblu.register {owner: @config.uuid}, (@newDevice) =>
          return done @newDevice.error if @newDevice?.error?
          @meshblu.subscribe {uuid: @device.uuid}, (data) =>
            return done new Error data.error if data.error?
            @meshblu.message {devices: [@config.uuid], topic: 'im-awesome'}, (data) =>
              return done data.error if data?.error?

      it 'should recieve a message', ->
        expect(@message.topic).to.deep.equal 'im-awesome'

  describe 'EVENT message', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.on 'message', (@message) =>
          done() if @message.topic == 'howdy'
        @meshblu.message {devices: [@config.uuid], topic: 'howdy'}

      it 'should not blow up', ->
        expect(true).to.be.true

  describe 'EVENT data', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.data uuid: @device.uuid, value: 1, (result)=>
          return done result.error if result?.error?
          done()

      it 'should not blow up', ->
        expect(true).to.be.true

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.data uuid: 'invalid-uuid', value: 1, (@result) => done()

      it 'should have an error property', ->
        expect(@result.error).to.exist

  describe 'EVENT getdata', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.getdata uuid: @device.uuid, token: @device.token, (@result) => done()

      it 'should have the correct result', ->
        expect(@result.data).to.be.an 'array'
        expect(@result.data).to.not.be.empty
