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
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
          request: {}
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.devices {uuid: 'invalid-uuid'}, =>
          @conx.once 'message', (@message) =>
            done()

      it 'should send a "devices-error" message', ->
        expect(@message.topic).to.deep.equal 'devices-error'
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
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
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
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
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
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
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
          request: {}
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
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
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
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
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
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
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
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
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
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
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
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
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
        expect(@message.payload).to.deep.equal {
          fromIp: '127.0.0.1'
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
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
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
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
        expect(@message.payload).to.deep.equal {
          fromIp: '127.0.0.1'
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
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
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
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
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
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
        expect(@message.payload).to.deep.equal {
          fromUuid: '66b2928b-a317-4bc3-893e-245946e9672a'
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

      it 'should send a "publickey" message', ->
        expect(@message.topic).to.deep.equal 'publickey'
        expect(@message.payload).to.deep.equal {
          request:
            uuid: @config.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.publicKey 'invalid-uuid', (error) =>
          @conx.once 'message', (@message) =>
            done()

      it 'should send an "publickey-error" message', ->
        expect(@message.topic).to.deep.equal 'publickey-error'
        expect(@message.payload).to.deep.equal {
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
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
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
        expect(@message.payload).to.deep.equal {
          fromUuid: '66b2928b-a317-4bc3-893e-245946e9672a'
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
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
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
        expect(@message.payload).to.deep.equal {
          fromUuid: '66b2928b-a317-4bc3-893e-245946e9672a'
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
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
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
        expect(@message.payload).to.deep.equal {
          fromUuid: '66b2928b-a317-4bc3-893e-245946e9672a'
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
        expect(@message.payload).to.deep.equal {
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
        expect(@message.payload).to.deep.equal {
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
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
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
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
          error: "Device not found"
          request:
            query: {uuid: 'invalid-uuid'}
            params: {foo: 'bar'}
        }
