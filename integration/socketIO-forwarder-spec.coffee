_ = require 'lodash'
path = require 'path'
meshblu = require 'meshblu'
MeshbluHTTP = require 'meshblu-http'
MeshbluSocketIO = require 'meshblu-socket.io'
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
    meshbluHTTP = new MeshbluHTTP _.pick @config, 'server', 'port'
    meshbluHTTP.register {}, (error, device) =>
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

          @eventForwarder.on 'message', (@message) =>
            done() if @message.topic == 'update'

      it 'should send an "update" message', ->
        expect(@message.topic).to.deep.equal 'update'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          request:
            query: {uuid: @device.uuid}
            params: {$set: {foo: 'bar'}}
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.update {uuid: 'invalid-uuid'}, {foo: 'bar'}, (error) =>
          return done new Error('update should have errored') unless error?

          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "devices-error" message', ->
        expect(@message.topic).to.deep.equal 'update-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @device.uuid
          error: "Device does not have sufficient permissions for update"
          request:
            query: {uuid: 'invalid-uuid'}
            params: {$set: {foo: 'bar'}}
        }

  describe 'EVENT identity', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.identity uuid: @device.uuid, token: @device.token, (error) =>
          return done error if error?

          @eventForwarder.on 'message', (message) =>
            if message.topic == 'identity'
              @message = message
              @eventForwarder.removeAllListeners 'message'
              done()

      it 'should send a "identity" message', ->
        expect(@message.topic).to.deep.equal 'identity'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          request:
            uuid: @device.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.identity uuid: 'invalid-uuid', token: 'invalid-token', (error) =>
          return done new Error('expected identity to raise an error') unless error?

          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "identity-error" message', ->
        expect(@message.topic).to.deep.equal 'identity-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          error: "Invalid Device UUID"
          request:
            uuid: 'invalid-uuid'
        }
