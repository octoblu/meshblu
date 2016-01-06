_ = require 'lodash'
path = require 'path'
url = require 'url'
MeshbluHTTP = require 'meshblu-http'
MeshbluConfig = require 'meshblu-config'
meshblu = require 'meshblu'
request = require 'request'

describe 'REST Forwarder Events', ->
  before (done) ->
    filename = path.join __dirname, 'meshblu.json'
    @config = new MeshbluConfig(filename: filename).toJSON()
    @meshblu = new MeshbluHTTP @config
    @conx = meshblu.createConnection
      server : @config.server
      port   : @config.port
      uuid   : @config.uuid
      token  : @config.token

    @conx.on 'ready', => done()
    @conx.on 'notReady', done

  afterEach ->
    @conx.removeAllListeners()

  it 'should get here', ->
    expect(true).to.be.true

  describe 'GET /devices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'devices'

        @meshblu.devices {}, =>

      it 'should send a "devices" message', ->
        expect(@message.topic).to.deep.equal 'devices'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request: {}
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.devices {uuid: 'invalid-uuid'}, =>
          @conx.on 'message', (@message) =>
            done() if @message.topic == 'devices-error'

      it 'should send a "devices-error" message', ->
        expect(@message.topic).to.deep.equal 'devices-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          error: "Devices not found"
          request:
            uuid: 'invalid-uuid'
        }

  describe 'GET /devices/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/devices/#{@config.uuid}"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'devices'

        request.get uri, auth: auth,  (error) =>
          return done error if error?

      it 'should send a "devices" message', ->
        expect(@message.topic).to.deep.equal 'devices'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            uuid: @config.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        pathname = "/devices/invalid-uuid"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'devices-error'
        request.get uri, auth: auth,  (error) =>
          return done error if error?

      it 'should send a "devices-error" message', ->
        expect(@message.topic).to.deep.equal 'devices-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          error: "Devices not found"
          request:
            uuid: 'invalid-uuid'
        }

  describe 'GET /v2/whoami', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'whoami'
        @meshblu.whoami (error) =>
          return done error if error?

      it 'should send a "whoami" message', ->
        expect(@message.topic).to.deep.equal 'whoami'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request: {}
        }

  describe 'GET /v2/devices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/v2/devices"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        query = {foo: 'bar'}
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'devices'
        request.get uri, auth: auth, qs: query, (error, response, body) =>
          return done error if error?
          return done body unless response.statusCode == 200

      it 'should send a "devices" message', ->
        expect(@message.topic).to.deep.equal 'devices'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            foo: 'bar'
        }

  describe 'GET /v2/devices/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'devices'

        @meshblu.device @config.uuid, (error) =>
          return done error if error?

      it 'should send a "devices" message', ->
        expect(@message.topic).to.deep.equal 'devices'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            uuid: @config.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'devices-error'
        @meshblu.device 'invalid-uuid', (error) =>

      it 'should send a "devices-error" message', ->
        expect(@message.topic).to.deep.equal 'devices-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          error: 'Devices not found'
          request:
            uuid: 'invalid-uuid'
        }

  describe 'PATCH /v2/devices/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'update'
        @meshblu.update @config.uuid, foo: 'bar', (error) =>
          return done error if error?

      it 'should send a "update" message', ->
        expect(@message.topic).to.deep.equal 'update'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            query: {uuid: @config.uuid}
            params: {$set: {foo: 'bar'}}
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'update-error'
        @meshblu.update @config.uuid, {$foo: 'bar'}, (error) =>

      it 'should send an "update-error" message', ->
        expect(@message.topic).to.deep.equal 'update-error'
        expect(@message.payload.fromUuid).to.equal @config.uuid
        expect(@message.payload.request.query.uuid).to.equal @config.uuid
        expect(@message.payload.request.params.$set.$foo).to.equal 'bar'

  describe 'PUT /v2/devices/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'update'
        @meshblu.updateDangerously @config.uuid, {$unset: {foo: 1}}, (error) =>
          return done error if error?

      it 'should send a "update" message', ->
        expect(@message.topic).to.deep.equal 'update'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            query: {uuid: @config.uuid}
            params: {$unset: {foo: 1}}
        }

    # describe 'when called with a valid request with a x-meshblu-forwarded-for header', ->
    #   beforeEach (done) ->
    #     @conx.on 'message', (@message) =>
    #       done() if @message.topic == 'update'
    #     @meshblu.updateDangerously @config.uuid, {$unset: {foo: 1}}, (error) =>
    #       return done error if error?
    #
    #   it 'should send a "update" message', ->
    #     expect(@message.topic).to.deep.equal 'update'
    #     expect(_.omit @message.payload, '_timestamp').to.deep.equal {
    #       fromUuid: @config.uuid
    #       request:
    #         query: {uuid: @config.uuid}
    #         params: {$unset: {foo: 1}}
    #     }


    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'update-error'
        @meshblu.update @config.uuid, {$foo: 'bar'}, (error) =>

      it 'should send an "update-error" message', ->
        expect(@message.topic).to.deep.equal 'update-error'
        expect(@message.payload.fromUuid).to.equal @config.uuid
        expect(@message.payload.request.query.uuid).to.equal @config.uuid
        expect(@message.payload.request.params.$set.$foo).to.equal 'bar'

  describe 'PUT /claimdevice/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'claimdevice'

        @meshblu.register configureWhitelist: ['*'], (error, device) =>
          return done error if error?

          @device = device
          pathname = "/claimdevice/#{@device.uuid}"
          uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
          auth = user: @config.uuid, pass: @config.token
          request.put uri, auth: auth,  (error) =>
            return done error if error?

      it 'should send a "claimdevice" message', ->
        expect(@message.topic).to.deep.equal 'claimdevice'
        expect(_.omit @message.payload, ['_timestamp', 'fromIp']).to.deep.equal {
          fromUuid: @config.uuid
          request:
            uuid: @device.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        pathname = "/claimdevice/invalid-uuid"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'claimdevice-error'
        request.put uri, auth: auth,  (error) =>
          return done error if error?

      it 'should send an "claimdevice-error" message', ->
        expect(@message.topic).to.deep.equal 'claimdevice-error'
        expect(_.omit @message.payload, ['_timestamp', 'fromIp']).to.deep.equal {
          fromUuid: @config.uuid
          error:    'Device not found'
          request:
            uuid: 'invalid-uuid'
        }

  describe 'GET /devices/:uuid/publickey', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'getpublickey'
        @meshblu.publicKey @config.uuid, (error) =>
          return done error if error?

      it 'should send a "getpublickey" message', ->
        expect(@message.topic).to.deep.equal 'getpublickey'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          request:
            uuid: @config.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'getpublickey-error'
        @meshblu.publicKey 'invalid-uuid', (error) =>

      it 'should send an "getpublickey-error" message', ->
        expect(@message.topic).to.deep.equal 'getpublickey-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          error: 'Device not found'
          request:
            uuid: 'invalid-uuid'
        }

  describe 'POST /devices/:uuid/token', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'resettoken'
        @meshblu.register configureWhitelist: ['*'], (error, device) =>
          return done error if error?

          @device = device
          @meshblu.resetToken @device.uuid, (error) =>
            return done error if error?

      it 'should send a "resettoken" message', ->
        expect(@message.topic).to.deep.equal 'resettoken'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            uuid: @device.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'resettoken-error'
        @meshblu.resetToken 'invalid-uuid', (error) =>

      it 'should send an "resettoken-error" message', ->
        expect(@message.topic).to.deep.equal 'resettoken-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          error:    'invalid device'
          request:
            uuid: 'invalid-uuid'
        }

  describe 'POST /devices/:uuid/tokens', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'generatetoken'
        @meshblu.register configureWhitelist: ['*'], (error, device) =>
          return done error if error?

          @device = device
          @meshblu.generateAndStoreToken @device.uuid, (error) =>
            return done error if error?

      it 'should send a "generatetoken" message', ->
        expect(@message.topic).to.deep.equal 'generatetoken'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            uuid: @device.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'generatetoken-error'
        @meshblu.generateAndStoreToken 'invalid-uuid', (error) =>

      it 'should send an "generatetoken-error" message', ->
        expect(@message.topic).to.deep.equal 'generatetoken-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          error:    'Device not found'
          request:
            uuid: 'invalid-uuid'
        }

  describe 'DELETE /devices/:uuid/tokens/:token', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'revoketoken'

        @meshblu.register configureWhitelist: ['*'], (error, device) =>
          return done error if error?

          @meshblu.generateAndStoreToken device.uuid, (error, device) =>
            return done error if error?

            @device = device
            @meshblu.revokeToken @device.uuid, @device.token, (error) =>
              return callback done error if error?

      it 'should send a "revoketoken" message', ->
        expect(@message.topic).to.deep.equal 'revoketoken'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            uuid: @device.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'revoketoken-error'
        @meshblu.revokeToken 'invalid-uuid', 'invalid-token', (error) =>

      it 'should send an "revoketoken-error" message', ->
        expect(@message.topic).to.deep.equal 'revoketoken-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          error:    'Device not found'
          request:
            uuid: 'invalid-uuid'
        }

  describe 'POST /devices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'register'
        @meshblu.register {}, (error, device) =>
          return done error if error?

      it 'should send a "register" message', ->
        expect(@message.topic).to.deep.equal 'register'

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'register-error'
        @meshblu.register uuid: 'not-allowed', (error) =>

      it 'should send an "register-error" message', ->
        expect(@message.topic).to.deep.equal 'register-error'
        expect(@message.payload.error).to.deep.equal 'Device not updated'

  describe 'PUT /devices/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/devices/#{@config.uuid}"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'update'
        request.put uri, auth: auth, json: {foo: 'bar'},  (error) =>
          return done error if error?

      it 'should send a "update" message', ->
        expect(@message.topic).to.deep.equal 'update'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            query: {uuid: @config.uuid}
            params: {foo: 'bar'}
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        pathname = "/devices/invalid-uuid"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'update-error'
        request.put uri, auth: auth, json: {foo: 'bar'},  (error) =>
          return done error if error?

      it 'should send a "update-error" message', ->
        expect(@message.topic).to.deep.equal 'update-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          error: "Device not found"
          request:
            query: {uuid: 'invalid-uuid'}
            params: {foo: 'bar'}
        }

  describe 'DELETE /devices/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'unregister'
        @meshblu.register { configureWhitelist: ['*'] }, (error, device) =>
          return done error if error?
          @device = device
          @meshblu.unregister uuid: @device.uuid, (error) =>
            return done error if error?

      it 'should send a "unregister" message', ->
        expect(@message.topic).to.deep.equal 'unregister'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            uuid: @device.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'unregister-error'
        @meshblu.unregister uuid: 'invalid-uuid', (error) =>

      it 'should send an "unregister-error" message', ->
        expect(@message.topic).to.deep.equal 'unregister-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          error:  'invalid device to unregister'
          fromUuid: @config.uuid
          request:
            uuid: 'invalid-uuid'
        }

  describe 'GET /mydevices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'devices'
        @meshblu.mydevices {}, =>

      it 'should send a "devices" message', ->
        expect(@message.topic).to.deep.equal 'devices'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            owner: @config.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'devices-error'
        @meshblu.mydevices {uuid: 'invalid-uuid'}, =>

      it 'should send a "devices-error" message', ->
        expect(@message.topic).to.deep.equal 'devices-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          error: "Devices not found"
          request:
            owner: @config.uuid
            uuid: 'invalid-uuid'
        }

  describe 'GET /subscribe/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/subscribe/#{@config.uuid}"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'subscribe'
        request.get uri, auth: auth, timeout: 10, =>

      it 'should send a "subscribe" message', ->
        expect(@message.topic).to.deep.equal 'subscribe'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            uuid: @config.uuid
        }

  describe 'GET /subscribe/:uuid/broadcast', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/subscribe/#{@config.uuid}/broadcast"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'subscribe'
        request.get uri, auth: auth, timeout: 10, =>

      it 'should send a "subscribe" message', ->
        expect(@message.topic).to.deep.equal 'subscribe'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            type: 'broadcast'
            uuid: @config.uuid
        }

  describe 'GET /subscribe/:uuid/received', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/subscribe/#{@config.uuid}/received"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'subscribe'
        request.get uri, auth: auth, timeout: 10, =>


      it 'should send a "subscribe" message', ->
        expect(@message.topic).to.deep.equal 'subscribe'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            type: 'received'
            uuid: @config.uuid
        }

  describe 'GET /subscribe/:uuid/sent', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/subscribe/#{@config.uuid}/sent"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'subscribe'
        request.get uri, auth: auth, timeout: 10, =>

      it 'should send a "subscribe" message', ->
        expect(@message.topic).to.deep.equal 'subscribe'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            type: 'sent'
            uuid: @config.uuid
        }

  describe 'GET /subscribe', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/subscribe"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token

        @conx.on 'message', (@message) =>
          done() if @message.topic == 'subscribe'
        request.get uri, auth: auth, timeout: 10, =>

      it 'should send a "subscribe" message', ->
        expect(@message.topic).to.deep.equal 'subscribe'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request: {}
        }

  describe 'GET /authenticate/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/authenticate/#{@config.uuid}"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token

        @conx.on 'message', (@message) =>
          done() if @message.topic == 'identity'
        request.get uri, json: {token: @config.token}, (error) =>

      it 'should send a "identity" message', ->
        expect(@message.topic).to.deep.equal 'identity'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          request:
            uuid: @config.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        pathname = "/authenticate/#{@config.uuid}"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'identity-error'
        request.get uri, (error) =>

      it 'should send a "identity-error" message', ->
        expect(@message.topic).to.deep.equal 'identity-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          error: "Device not found or token not valid"
          request:
            uuid: @config.uuid
        }

  describe 'POST /messages', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'message'
        @meshblu.message {devices: ['some-uuid']}, =>

      it 'should send a "message" message', ->
        expect(@message.topic).to.deep.equal 'message'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            devices: ['some-uuid']
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'message-error'
        @meshblu.message {}, =>

      it 'should send a "message-error" message', ->
        expect(@message.topic).to.deep.equal 'message-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          error: "Invalid Message Format"
          request: {}
        }

  describe 'POST /data/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/data/#{@config.uuid}"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'data'
        request.post uri, auth: auth, json: {value: 1}, (error) =>

      it 'should send a "data" message', ->
        expect(@message.topic).to.deep.equal 'data'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            value: 1
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        pathname = "/data/invalid-uuid"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'data-error'
        request.post uri, auth: auth, json: {value: 1}, (error) =>

      it 'should send a "data-error" message', ->
        expect(@message.topic).to.deep.equal 'data-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          error: "Device not found"
          request:
            value: 1
        }

  describe 'GET /data/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/data/#{@config.uuid}"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'subscribe'
        request.get uri, auth: auth, (error) =>

      it 'should send a "subscribe" message', ->
        expect(@message.topic).to.deep.equal 'subscribe'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            type: 'data'
            uuid: @config.uuid
        }
