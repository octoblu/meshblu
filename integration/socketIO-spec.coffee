_ = require 'lodash'
path = require 'path'
meshblu = require 'meshblu'
MeshbluHTTP = require 'meshblu-http'
MeshbluSocketIO = require 'meshblu-socket.io'
MeshbluConfig = require 'meshblu-config'

describe 'SocketLogic Events', ->
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
    @meshbluHTTP = new MeshbluHTTP @config
    @meshbluHTTP.register {}, (error, device) =>
      return done error if error?

      @device = device
      @meshblu = new MeshbluSocketIO uuid: @device.uuid, token: @device.token, host: @config.host, protocol: @config.protocol, socketIOOptions: {forceNew: true}
      @meshblu.connect done

  it 'should get here', ->
    expect(true).to.be.true

  describe 'EVENT update', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.update {uuid: @device.uuid}, {foo: 'bar'}, (error) =>
          return done error if error?
          @meshbluHTTP.whoami (error, @newDevice)=> done(error)

      it 'should have foo:bar', ->
        expect(@newDevice.foo).to.equal 'bar'
