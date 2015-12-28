_ = require 'lodash'
path = require 'path'
meshblu = require 'meshblu'
MeshbluConfig = require 'meshblu-config'
MeshbluMQTT = require 'meshblu-mqtt'
MeshbluHTTP = require 'meshblu-http'

describe 'MQTT Forwarder Events', ->
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
    meshbluHTTP = new MeshbluHTTP _.pick @config, 'server', 'port'
    meshbluHTTP.register {}, (error, device) =>
      return done error if error?

      @device = device
      @meshblu = new MeshbluMQTT uuid: @device.uuid, token: @device.token, hostname: @config.server
      @meshblu.connect => done()

  it 'should get here', ->
    expect(true).to.be.true

  describe 'EVENT whoami', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.whoami (error, data) =>
          return done new Error(error.message) if error?

          @eventForwarder.on 'message', (message) =>
            if message.topic == 'whoami'
              @message = message
              @eventForwarder.removeAllListeners 'message'
              done()

      it 'should send a "whoami" message', ->
        expect(@message.topic).to.deep.equal 'whoami'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request: {}
        }

  describe 'EVENT update', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.update uuid: @device.uuid, foo: 'bar', (error) =>
          return done new Error(error.message) if error?
          @eventForwarder.once 'message', (@message) =>
            done()

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
        @meshblu.update uuid: 'invalid-uuid', foo: 'bar', (error) =>
          return done new Error('Expected an error') unless error?
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send an "update-error" message', ->
        expect(@message.topic).to.deep.equal 'update-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          error: "Device not found"
          request:
            query: {uuid: 'invalid-uuid'}
            params: {$set: {foo: 'bar', uuid: 'invalid-uuid'}}
        }

  describe 'EVENT getPublicKey', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.getPublicKey uuid: @config.uuid, (error) =>
          return done error if error
          @eventForwarder.on 'message', (message) =>
            if message.topic == 'getpublickey'
              @message = message
              @eventForwarder.removeAllListeners 'message'
              done()

      it 'should send a "getpublickey" message', ->
        expect(@message.topic).to.deep.equal 'getpublickey'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          request:
            uuid: @config.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.getPublicKey uuid: 'invalid-uuid', (error) =>
          return done new Error('Expected an error') unless error?
          @eventForwarder.once 'message', (@message) =>
            done()

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
        meshbluHTTP = new MeshbluHTTP _.pick @config, 'server', 'port'
        meshbluHTTP.register configureWhitelist: ['*'], (error, device) =>
          return done error if error?

          @newDevice = device
          @meshblu.resetToken uuid: @newDevice.uuid, (error, data) =>
            return done new Error error.message if error?
            @eventForwarder.on 'message', (message) =>
              if message.topic == 'resettoken'
                @message = message
                @eventForwarder.removeAllListeners 'message'
                done()

      it 'should send a "resettoken" message', ->
        expect(@message.topic).to.deep.equal 'resettoken'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request:
            uuid: @newDevice.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.resetToken uuid: 'invalid-uuid', (error) =>
          return done new Error('Expected an error') unless error?
          @eventForwarder.once 'message', (@message) =>
            done()

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
        meshbluHTTP = new MeshbluHTTP _.pick @config, 'server', 'port'
        meshbluHTTP.register configureWhitelist: ['*'], (error, device) =>
          return done error if error?

          @newDevice = device
          @meshblu.generateAndStoreToken uuid: @newDevice.uuid, (error, data) =>
            return done new Error error if error?
            return done new Error error.message if data.error?
            @eventForwarder.once 'message', (@message) =>
              done()

      it 'should send a "generatetoken" message', ->
        expect(@message.topic).to.deep.equal 'generatetoken'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
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
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          error:    'Device not found'
          request:
            uuid: 'invalid-uuid'
        }

  describe 'EVENT message', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.message devices: ['some-uuid']
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
