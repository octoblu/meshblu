_ = require 'lodash'
path = require 'path'
meshblu = require 'meshblu'
MeshbluConfig = require 'meshblu-config'
MeshbluMQTT = require 'meshblu-mqtt'
MeshbluHTTP = require 'meshblu-http'

describe 'MQTT Events', ->
  before (done) ->
    filename = path.join __dirname, 'meshblu.json'
    @config = new MeshbluConfig(filename: filename).toJSON()
    @conx = meshblu.createConnection
      server : @config.server
      port   : @config.port
      uuid   : @config.uuid
      token  : @config.token

    @conx.on 'ready', => done()
    @conx.on 'notReady', done

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
        @meshblu.whoami (error, @newDevice) =>
          return done new Error(error.message) if error?
          done()

      it 'should have a valid uuid', ->
        expect(@newDevice.uuid).to.deep.equal @device.uuid

  describe 'EVENT update', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.update uuid: @device.uuid, foo: 'bar', (error) =>
          return done new Error(error.message) if error?
          @meshblu.whoami (error, @updatedDevice) => done(error)

      it "shoud have an updated device with valid uuid and foo", ->
        expect(@updatedDevice.uuid).to.equal @device.uuid
        expect(@updatedDevice.foo).to.equal 'bar'

  describe 'EVENT getPublicKey', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.getPublicKey uuid: @config.uuid, (error, @publicKey) =>
          return done error if error
          done()

      it 'should have a valid publicKey', ->
        expect(@publicKey).to.exist

  describe 'EVENT resetToken', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        meshbluHTTP = new MeshbluHTTP _.pick @config, 'server', 'port'
        meshbluHTTP.register configureWhitelist: ['*'], (error, @newDevice) =>
          return done error if error?
          @meshblu.resetToken uuid: @newDevice.uuid, (error, @newTokenDevice) =>
            return done new Error error.message if error?
            done()

      it 'should have a new token', ->
        expect(@newDevice.token).to.not.equal @newTokenDevice.token

  describe 'EVENT generateAndStoreToken', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        meshbluHTTP = new MeshbluHTTP _.pick @config, 'server', 'port'
        meshbluHTTP.register configureWhitelist: ['*'], (error, @newDevice) =>
          return done error if error?
          @meshblu.generateAndStoreToken uuid: @newDevice.uuid, (error, @result) =>
            return done new Error error.message if error?
            done()

      it 'should have a new token', ->
        expect(@result.token).to.exist

    describe 'when called with a valid tag request', ->
      beforeEach (done) ->
        meshbluHTTP = new MeshbluHTTP _.pick @config, 'server', 'port'
        meshbluHTTP.register configureWhitelist: ['*'], (error, @newDevice) =>
          return done error if error?
          @meshblu.generateAndStoreToken uuid: @newDevice.uuid, tag: 'some-tag', (error, @result) =>
            return done new Error error.message if error?
            done()

      it 'should have a new token', ->
        expect(@result.token).to.exist

      it 'should have a new token', ->
        expect(@result.tag).to.equal 'some-tag'

  describe 'EVENT message', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.message devices: [@device.uuid], topic: 'sweet'
        @meshblu.on 'message', (@message) => done() if @message.topic == 'sweet'

      it 'should have the correct message', ->
        expect(@message.devices).to.deep.equal [@device.uuid]
