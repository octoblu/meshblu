_ = require 'lodash'
path = require 'path'
url = require 'url'
MeshbluHTTP = require 'meshblu-http'
MeshbluConfig = require 'meshblu-config'
meshblu = require 'meshblu'
request = require 'request'

describe 'REST', ->
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

  it 'should get here', ->
    expect(true).to.be.true

  describe 'GET /devices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.devices {}, =>
          @conx.once 'message', (@message) =>
            done()

      it 'should send a "devices" message', ->
        expect(@message.topic).to.deep.equal 'devices'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request: {}
        }

    describe 'when called with a valid uuid and token', ->
      beforeEach (done) ->
        @meshblu.register discoverWhitelist: [], (error, @newDevice) =>
          @meshblu.devices uuid: @newDevice.uuid, token: @newDevice.token, (error, @response)=>
            done()

      it 'should receive a device array', ->
        expect(@response.devices).to.exist

    describe 'when called with a valid uuid and invalid token', ->
      beforeEach (done) ->
        @meshblu.register discoverWhitelist: [], (error, @newDevice) =>
          @meshblu.devices uuid: @newDevice.uuid, token: 'bad-token', (error, @response)=>
            done()

      it 'should not receive a device array', ->
        expect(@response.devices).to.not.exist

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.devices {uuid: 'invalid-uuid'}, =>
          @conx.once 'message', (@message) =>
            done()

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
        request.get uri, auth: auth,  (error) =>
          return done error if error?
          @conx.once 'message', (@message) =>
            done()

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
        request.get uri, auth: auth,  (error) =>
          return done error if error?
          @conx.once 'message', (@message) =>
            done()

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
        @meshblu.whoami (error) =>
          return done error if error?
          @conx.once 'message', (@message) =>
            done()

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
        request.get uri, auth: auth, qs: query, (error, response, body) =>
          return done error if error?
          return done body unless response.statusCode == 200
          @conx.once 'message', (@message) =>
            done()

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
        @meshblu.device @config.uuid, (error) =>
          return done error if error?
          @conx.once 'message', (@message) =>
            done()

      it 'should send a "devices" message', ->
        expect(@message.topic).to.deep.equal 'devices'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            uuid: @config.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.device 'invalid-uuid', (error) =>
          @conx.once 'message', (@message) =>
            done()

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
        @meshblu.update @config.uuid, foo: 'bar', (error) =>
          return done error if error?
          @conx.once 'message', (@message) =>
            done()

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
        @meshblu.update @config.uuid, {$foo: 'bar'}, (error) =>
          @conx.once 'message', (@message) =>
            done()

      it 'should send an "update-error" message', ->
        expect(@message.topic).to.deep.equal 'update-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          error: "The dollar ($) prefixed field '$foo' in '$foo' is not valid for storage."
          request:
            query: {uuid: @config.uuid}
            params: {$set: {"$foo": 'bar'}}
        }

  describe 'PUT /v2/devices/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.updateDangerously @config.uuid, {$unset: {foo: 1}}, (error) =>
          return done error if error?
          @conx.once 'message', (@message) =>
            done()

      it 'should send a "update" message', ->
        expect(@message.topic).to.deep.equal 'update'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            query: {uuid: @config.uuid}
            params: {$unset: {foo: 1}}
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.update @config.uuid, {$foo: 'bar'}, (error) =>
          @conx.once 'message', (@message) =>
            done()

      it 'should send an "update-error" message', ->
        expect(@message.topic).to.deep.equal 'update-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          error: "The dollar ($) prefixed field '$foo' in '$foo' is not valid for storage."
          request:
            query: {uuid: @config.uuid}
            params: {$set: {"$foo": 'bar'}}
        }

  describe 'GET /localdevices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/localdevices"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.get uri, auth: auth,  (error) =>
          return done error if error?
          @conx.once 'message', (@message) =>
            done()

      it 'should send a "localdevices" message', ->
        expect(@message.topic).to.deep.equal 'localdevices'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromIp: '127.0.0.1'
          fromUuid: @config.uuid
          request: {}
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        pathname = "localdevices"
        query = uuid: 'invalid-uuid'
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.get uri, auth: auth, qs: query,  (error) =>
          return done error if error?
          @conx.once 'message', (@message) =>
            done()

      it 'should send a "localdevices-error" message', ->
        expect(@message.topic).to.deep.equal 'localdevices-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          fromIp: "127.0.0.1"
          error: "Devices not found"
          request:
            uuid: 'invalid-uuid'
        }

  describe 'GET /unclaimeddevices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/unclaimeddevices"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.get uri, auth: auth,  (error) =>
          return done error if error?
          @conx.once 'message', (@message) =>
            done()

      it 'should send a "localdevices" message', ->
        expect(@message.topic).to.deep.equal 'localdevices'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromIp: '127.0.0.1'
          fromUuid: @config.uuid
          request: {}
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        pathname = "/unclaimeddevices"
        query = uuid: 'invalid-uuid'
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.get uri, auth: auth, qs: query,  (error) =>
          return done error if error?
          @conx.once 'message', (@message) =>
            done()

      it 'should send a "localdevices-error" message', ->
        expect(@message.topic).to.deep.equal 'localdevices-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          fromIp: "127.0.0.1"
          error: "Devices not found"
          request:
            uuid: 'invalid-uuid'
        }

  describe 'PUT /claimdevice/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register configWhitelist: ['*'], (error, device) =>
          return done error if error?

          @device = device
          pathname = "/claimdevice/#{@device.uuid}"
          uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
          auth = user: @config.uuid, pass: @config.token
          request.put uri, auth: auth,  (error) =>
            return done error if error?
            @conx.once 'message', (@message) =>
              done()

      it 'should send a "claimdevice" message', ->
        expect(@message.topic).to.deep.equal 'claimdevice'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          fromIp:   "127.0.0.1"
          request:
            uuid: @device.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        pathname = "/claimdevice/invalid-uuid"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.put uri, auth: auth,  (error) =>
          return done error if error?
          @conx.once 'message', (@message) =>
            done()

      it 'should send an "claimdevice-error" message', ->
        expect(@message.topic).to.deep.equal 'claimdevice-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          fromIp:   '127.0.0.1'
          error:    'Device not found'
          request:
            uuid: 'invalid-uuid'
        }

  describe 'GET /devices/:uuid/publickey', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.publicKey @config.uuid, (error) =>
          return done error if error?
          @conx.once 'message', (@message) =>
            done()

      it 'should send a "getpublickey" message', ->
        expect(@message.topic).to.deep.equal 'getpublickey'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          request:
            uuid: @config.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.publicKey 'invalid-uuid', (error) =>
          @conx.once 'message', (@message) =>
            done()

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
        @meshblu.register configWhitelist: ['*'], (error, device) =>
          return done error if error?

          @device = device
          @meshblu.resetToken @device.uuid, (error) =>
            return done error if error?
            @conx.once 'message', (@message) =>
              done()

      it 'should send a "resettoken" message', ->
        expect(@message.topic).to.deep.equal 'resettoken'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            uuid: @device.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.resetToken 'invalid-uuid', (error) =>
          @conx.once 'message', (@message) =>
            done()

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
        @meshblu.register configWhitelist: ['*'], (error, device) =>
          return done error if error?

          @device = device
          @meshblu.generateAndStoreToken @device.uuid, (error) =>
            return done error if error?
            @conx.once 'message', (@message) =>
              done()

      it 'should send a "generatetoken" message', ->
        expect(@message.topic).to.deep.equal 'generatetoken'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            uuid: @device.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.generateAndStoreToken 'invalid-uuid', (error) =>
          @conx.once 'message', (@message) =>
            done()

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
        @meshblu.register configWhitelist: ['*'], (error, device) =>
          return done error if error?

          @meshblu.generateAndStoreToken device.uuid, (error, device) =>
            return done error if error?

            @device = device
            @meshblu.revokeToken @device.uuid, @device.token, (error) =>
              return callback done error if error?
              @conx.once 'message', (@message) =>
                done()

      it 'should send a "revoketoken" message', ->
        expect(@message.topic).to.deep.equal 'revoketoken'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            uuid: @device.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.revokeToken 'invalid-uuid', 'invalid-token', (error) =>
          @conx.once 'message', (@message) =>
            done()

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
        @meshblu.register {}, (error, device) =>
          return done error if error?

          @conx.once 'message', (@message) =>
            done()

      it 'should send a "register" message', ->
        expect(@message.topic).to.deep.equal 'register'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          request:
            ipAddress: '127.0.0.1'
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.register uuid: 'not-allowed', (error) =>
          @conx.once 'message', (@message) =>
            done()

      it 'should send an "register-error" message', ->
        expect(@message.topic).to.deep.equal 'register-error'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          error:  'Device not updated'
          request:
            uuid: 'not-allowed'
            ipAddress: '127.0.0.1'
        }

  describe 'PUT /devices/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/devices/#{@config.uuid}"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.put uri, auth: auth, json: {foo: 'bar'},  (error) =>
          return done error if error?
          @conx.once 'message', (@message) =>
            done()

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
        request.put uri, auth: auth, json: {foo: 'bar'},  (error) =>
          return done error if error?
          @conx.once 'message', (@message) =>
            done()

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
        @meshblu.register {}, (error, device) =>
          return done error if error?

          @device = device
          @meshblu.unregister uuid: @device.uuid, (error) =>
            return done error if error?
            @conx.once 'message', (@message) =>
              done()

      it 'should send a "unregister" message', ->
        expect(@message.topic).to.deep.equal 'unregister'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            uuid: @device.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.unregister uuid: 'invalid-uuid', (error) =>
          @conx.once 'message', (@message) =>
            done()

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
        @meshblu.mydevices {}, =>
          @conx.once 'message', (@message) =>
            done()

      it 'should send a "devices" message', ->
        expect(@message.topic).to.deep.equal 'devices'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            owner: @config.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.mydevices {uuid: 'invalid-uuid'}, =>
          @conx.once 'message', (@message) =>
            done()

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

        request.get uri, auth: auth, timeout: 10, =>
        @conx.once 'message', (@message) =>
          done()

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

        request.get uri, auth: auth, timeout: 10, =>
        @conx.once 'message', (@message) =>
          done()

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

        request.get uri, auth: auth, timeout: 10, =>
        @conx.once 'message', (@message) =>
          done()

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

        request.get uri, auth: auth, timeout: 10, =>
        @conx.once 'message', (@message) =>
          done()

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

        request.get uri, auth: auth, timeout: 10, =>
        @conx.once 'message', (@message) =>
          done()

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

        request.get uri, json: {token: @config.token}, (error) =>
          @conx.once 'message', (@message) =>
            done()

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

        request.get uri, (error) =>
          @conx.once 'message', (@message) =>
            done()

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
        @meshblu.message {devices: ['some-uuid']}, =>
          @conx.once 'message', (@message) =>
            done()

      it 'should send a "message" message', ->
        expect(@message.topic).to.deep.equal 'message'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            devices: ['some-uuid']
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.message {}, =>
          @conx.once 'message', (@message) =>
            done()

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

        request.post uri, auth: auth, json: {value: 1}, (error) =>
          @conx.once 'message', (@message) =>
            done()

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

        request.post uri, auth: auth, json: {value: 1}, (error) =>
          @conx.once 'message', (@message) =>
            done()

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

        request.get uri, auth: auth, (error) =>
          @conx.once 'message', (@message) =>
            done()

      it 'should send a "subscribe" message', ->
        expect(@message.topic).to.deep.equal 'subscribe'
        expect(_.omit @message.payload, '_timestamp').to.deep.equal {
          fromUuid: @config.uuid
          request:
            type: 'data'
            uuid: @config.uuid
        }
