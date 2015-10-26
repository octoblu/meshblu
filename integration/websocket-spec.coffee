_ = require 'lodash'
path = require 'path'
debug = require('debug')('meshblu:integration:websocket')
MeshbluConfig = require 'meshblu-config'
MeshbluHTTP = require 'meshblu-http'
MeshbluWebsocket = require 'meshblu-websocket'
MeshbluSocketLogic = require 'meshblu'

describe 'WebSocket Events', ->
  before (done) ->
    filename = path.join __dirname, 'meshblu.json'
    @config = new MeshbluConfig(filename: filename).toJSON()
    meshbluHTTP = new MeshbluHTTP _.pick @config, 'server', 'port'
    meshbluHTTP.register {}, (error, device) =>
      return done error if error?

      @device = device
      @meshblu = new MeshbluWebsocket uuid: @device.uuid, token: @device.token, host: @config.host, protocol: @config.protocol
      @meshblu.connect (error) =>
        done error

  beforeEach (done) ->
    _.delay done, 100

  afterEach ->
    @meshblu.removeAllListeners()

  it 'should get here', ->
    expect(true).to.be.true

  describe 'EVENT devices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.devices {}
        @meshblu.on 'devices', (@result) => done()

      it 'should have the devices', ->
        expect(@result.devices).to.be.an 'array'
        expect(@result.devices).to.not.be.empty

  describe 'EVENT device', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.device @device.uuid
        @meshblu.on 'device', (@theDevice) => done()

      it 'should have a device', ->
        expect(@theDevice.uuid).to.equal @device.uuid

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.device 'invalid-uuid'
        @meshblu.on 'error', (@error) => done()
        @meshblu.on 'device', =>

      it 'should have an error', ->
        expect(@error.message).to.equal 'unauthorized'

  describe 'EVENT whoami', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.whoami()
        @meshblu.on 'whoami', (@theDevice) => done()

      it 'should have a device', ->
        expect(@theDevice.uuid).to.equal @device.uuid

  describe 'EVENT update', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.update {uuid: @device.uuid}, {foo: 'bar'}
        @meshblu.once 'updated', (@theDevice) =>
          @meshblu.whoami()
          @meshblu.on 'whoami', (@getDevice) => done()

      it 'should have a the device', ->
        expect(@theDevice.uuid).to.equal @device.uuid

      it 'should have a the updated property', ->
        expect(@getDevice.foo).to.equal 'bar'

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.update {uuid: 'invalid-uuid'}, {foo: 'bar'}
        @meshblu.on 'error', (@error) => done()

      it 'should have an error', ->
        expect(@error.message).to.equal 'Device does not have sufficient permissions for update'

  describe 'EVENT register', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.once 'registered', (@registeredDevice) => done()
        @meshblu.register {foo: 'bar'}

      it 'should register a device', ->
        expect(@registeredDevice.foo).to.equal 'bar'

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.register uuid: 'not-allowed'
        @meshblu.on 'error', (@error) => done()

      it 'should have an error', ->
        expect(@error.message).to.equal 'Device not updated'

  describe 'EVENT unregister', ->
    describe 'when called with a valid request without token', ->
      beforeEach (done) ->
        @meshblu.register {configureWhitelist: [@device.uuid]}
        @meshblu.once 'registered', (data) =>
          @newDevice = data
          done()

      beforeEach (done) ->
        @meshblu.unregister uuid: @newDevice.uuid
        @meshblu.on 'unregistered', (@theDevice) => done()

      it 'should have unregistered', ->
        expect(@theDevice.uuid).to.equal @newDevice.uuid

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.unregister uuid: 'invalid-uuid'
        @meshblu.on 'error', (@error) => done()

      it 'should have a invalid uuid', ->
        expect(@error.message).to.deep.equal 'invalid device to unregister'

  describe 'EVENT mydevices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register  owner: @device.uuid, discoverWhitelist: [@device.uuid]
        @meshblu.once 'registered', (data) =>
          @newDevice = data
          done()

      beforeEach (done) ->
        @meshblu.mydevices()
        @meshblu.on 'mydevices', (@devices) => done()

      it 'should be an array and not empty', ->
        expect(@devices).to.be.an 'array'
        expect(@devices).to.be.not.empty

  describe 'EVENT subscribe', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register {hello: 'hello', owner: @device.uuid}
        @meshblu.on 'registered', (@newDevice) =>
          @meshblu.subscribe @newDevice.uuid
          @meshblu.message {devices: [@device.uuid], topic: 'hello'}
        @meshblu.on 'message', (@message) => done() if @message.topic == 'hello'

      it 'should have a message', ->
        expect(@message.devices).to.deep.equal [@device.uuid]
        expect(@message.topic).to.equal 'hello'

  describe 'EVENT message', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.on 'message', (@message) =>
          done() if @message.topic == 'howdy'
        @meshblu.message {devices: [@device.uuid], topic: 'howdy'}

      it 'should have a recieved message', ->
        expect(@message.devices).to.deep.equal [@device.uuid]
