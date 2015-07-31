_ = require 'lodash'
path = require 'path'
meshblu = require 'meshblu'
MeshbluConfig = require 'meshblu-config'

describe.only 'SocketLogic Events', ->
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
    @meshblu = meshblu.createConnection _.pick(@config, 'server', 'port')
    @meshblu.on 'ready', (@device) => done()
    @meshblu.on 'notReady', done

  it 'should get here', ->
    expect(true).to.be.true

  describe 'EVENT devices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.devices {}, (data) =>
          return done new Error(data.error) if data.error?
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "devices" message', ->
        expect(@message.topic).to.deep.equal 'devices'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          request: {}
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.devices {uuid: 'invalid-uuid'}, =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "devices-error" message', ->
        expect(@message.topic).to.deep.equal 'devices-error'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          error: "Devices not found"
          request:
            uuid: 'invalid-uuid'
        }

  describe 'EVENT devices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.device {uuid: @device.uuid}, (data) =>
          return done new Error(data.error) if data.error?
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "devices" message', ->
        expect(@message.topic).to.deep.equal 'devices'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          request:
            uuid: @device.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.device {uuid: 'invalid-uuid'}, (data) =>
          return done new Error(data.error) if data.error?
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "devices-error" message', ->
        expect(@message.topic).to.deep.equal 'devices-error'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          error: "Devices not found"
          request:
            uuid: 'invalid-uuid'
        }

  describe 'EVENT whoami', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.whoami {}, (data) =>
          return done new Error(data.error) if data.error?
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "whoami" message', ->
        expect(@message.topic).to.deep.equal 'whoami'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          request: {}
        }

  describe 'EVENT update', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.update uuid: @device.uuid, foo: 'bar', (data) =>
          return done new Error(data.error) if data.error?
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "update" message', ->
        expect(@message.topic).to.deep.equal 'update'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          request:
            query: {uuid: @device.uuid}
            params: {$set: {foo: 'bar', uuid: @device.uuid}}
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.update uuid: 'invalid-uuid', foo: 'bar', (error) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send an "update-error" message', ->
        expect(@message.topic).to.deep.equal 'update-error'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          error: "Device not found"
          request:
            query: {uuid: 'invalid-uuid'}
            params: {$set: {foo: 'bar', uuid: 'invalid-uuid'}}
        }

  describe 'EVENT localdevices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.localdevices (error) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "localdevices" message', ->
        expect(@message.topic).to.deep.equal 'localdevices'
        expect(@message.payload).to.deep.equal {
          fromIp: '127.0.0.1'
          fromUuid: @device.uuid
          request: {}
        }

  describe 'EVENT unclaimeddevices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.unclaimeddevices {}, (error) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "unclaimeddevices" message', ->
        expect(@message.topic).to.deep.equal 'unclaimeddevices'
        expect(@message.payload).to.deep.equal {
          fromIp: '127.0.0.1'
          fromUuid: @device.uuid
          request: {}
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.unclaimeddevices {uuid: 'invalid-uuid'}, (error) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send an "unclaimeddevices-error" message', ->
        expect(@message.topic).to.deep.equal 'unclaimeddevices-error'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          fromIp: "127.0.0.1"
          error: "Devices not found"
          request:
            uuid: 'invalid-uuid'
        }

  describe 'EVENT claimdevice', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register configWhitelist: ['*'], (data) =>
          return done new Error data.error if data.error?

          @newDevice = data
          @meshblu.claimdevice uuid: @newDevice.uuid, (data) =>
            return done new Error data.error if data.error?
            @eventForwarder.once 'message', (@message) =>
              done()

      it 'should send a "claimdevice" message', ->
        expect(@message.topic).to.deep.equal 'claimdevice'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          fromIp:   "127.0.0.1"
          request:
            uuid: @newDevice.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.claimdevice uuid: 'invalid-uuid', (data) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send an "claimdevice-error" message', ->
        expect(@message.topic).to.deep.equal 'claimdevice-error'
        expect(@message.payload).to.deep.equal {
          fromUuid: @device.uuid
          fromIp:   '127.0.0.1'
          error:    'Device not found'
          request:
            uuid: 'invalid-uuid'
        }

  xdescribe 'GET /devices/:uuid/publickey', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.publicKey @config.uuid, (error) =>
          return done error if error?
          @eventForwarder.once 'message', (@message) =>
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
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send an "publickey-error" message', ->
        expect(@message.topic).to.deep.equal 'publickey-error'
        expect(@message.payload).to.deep.equal {
          error: 'Device not found'
          request:
            uuid: 'invalid-uuid'
        }

  xdescribe 'POST /devices/:uuid/token', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register configWhitelist: ['*'], (error, device) =>
          return done error if error?

          @device = device
          @meshblu.resetToken @device.uuid, (error) =>
            return done error if error?
            @eventForwarder.once 'message', (@message) =>
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
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send an "resettoken-error" message', ->
        expect(@message.topic).to.deep.equal 'resettoken-error'
        expect(@message.payload).to.deep.equal {
          fromUuid: '66b2928b-a317-4bc3-893e-245946e9672a'
          error:    'invalid device'
          request:
            uuid: 'invalid-uuid'
        }

  xdescribe 'POST /devices/:uuid/tokens', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register configWhitelist: ['*'], (error, device) =>
          return done error if error?

          @device = device
          @meshblu.generateAndStoreToken @device.uuid, (error) =>
            return done error if error?
            @eventForwarder.once 'message', (@message) =>
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
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send an "generatetoken-error" message', ->
        expect(@message.topic).to.deep.equal 'generatetoken-error'
        expect(@message.payload).to.deep.equal {
          fromUuid: '66b2928b-a317-4bc3-893e-245946e9672a'
          error:    'Device not found'
          request:
            uuid: 'invalid-uuid'
        }

  xdescribe 'DELETE /devices/:uuid/tokens/:token', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register configWhitelist: ['*'], (error, device) =>
          return done error if error?

          @meshblu.generateAndStoreToken device.uuid, (error, device) =>
            return done error if error?

            @device = device
            @meshblu.revokeToken @device.uuid, @device.token, (error) =>
              return callback done error if error?
              @eventForwarder.once 'message', (@message) =>
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
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send an "revoketoken-error" message', ->
        expect(@message.topic).to.deep.equal 'revoketoken-error'
        expect(@message.payload).to.deep.equal {
          fromUuid: '66b2928b-a317-4bc3-893e-245946e9672a'
          error:    'Device not found'
          request:
            uuid: 'invalid-uuid'
        }

  xdescribe 'POST /devices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register {}, (error, device) =>
          return done error if error?

          @eventForwarder.once 'message', (@message) =>
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
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send an "register-error" message', ->
        expect(@message.topic).to.deep.equal 'register-error'
        expect(@message.payload).to.deep.equal {
          error:  'Device not updated'
          request:
            uuid: 'not-allowed'
            ipAddress: '127.0.0.1'
        }

  xdescribe 'PUT /devices/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/devices/#{@config.uuid}"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.put uri, auth: auth, json: {foo: 'bar'},  (error) =>
          return done error if error?
          @eventForwarder.once 'message', (@message) =>
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
          @eventForwarder.once 'message', (@message) =>
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

  xdescribe 'DELETE /devices/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register {}, (error, device) =>
          return done error if error?

          @device = device
          @meshblu.unregister uuid: @device.uuid, (error) =>
            return done error if error?
            @eventForwarder.once 'message', (@message) =>
              done()

      it 'should send a "unregister" message', ->
        expect(@message.topic).to.deep.equal 'unregister'
        expect(@message.payload).to.deep.equal {
          fromUuid: @config.uuid
          request:
            query: {uuid: @device.uuid}
            params: {}
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.unregister uuid: 'invalid-uuid', (error) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send an "unregister-error" message', ->
        expect(@message.topic).to.deep.equal 'unregister-error'
        expect(@message.payload).to.deep.equal {
          error:  'invalid device to unregister'
          fromUuid: @config.uuid
          request:
            query: {uuid: 'invalid-uuid'}
            params: {}
        }

  xdescribe 'GET /mydevices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.mydevices {}, =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "devices" message', ->
        expect(@message.topic).to.deep.equal 'devices'
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
          request:
            owner: @config.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.mydevices {uuid: 'invalid-uuid'}, =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "devices-error" message', ->
        expect(@message.topic).to.deep.equal 'devices-error'
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
          error: "Devices not found"
          request:
            owner: @config.uuid
            uuid: 'invalid-uuid'
        }

  xdescribe 'GET /subscribe/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/subscribe/#{@config.uuid}"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token

        request.get uri, auth: auth, timeout: 10, =>
        @eventForwarder.once 'message', (@message) =>
          done()

      it 'should send a "subscribe" message', ->
        expect(@message.topic).to.deep.equal 'subscribe'
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
          request:
            uuid: @config.uuid
        }

  xdescribe 'GET /subscribe/:uuid/broadcast', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/subscribe/#{@config.uuid}/broadcast"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token

        request.get uri, auth: auth, timeout: 10, =>
        @eventForwarder.once 'message', (@message) =>
          done()

      it 'should send a "subscribe" message', ->
        expect(@message.topic).to.deep.equal 'subscribe'
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
          request:
            type: 'broadcast'
            uuid: @config.uuid
        }

  xdescribe 'GET /subscribe/:uuid/received', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/subscribe/#{@config.uuid}/received"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token

        request.get uri, auth: auth, timeout: 10, =>
        @eventForwarder.once 'message', (@message) =>
          done()

      it 'should send a "subscribe" message', ->
        expect(@message.topic).to.deep.equal 'subscribe'
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
          request:
            type: 'received'
            uuid: @config.uuid
        }

  xdescribe 'GET /subscribe/:uuid/sent', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/subscribe/#{@config.uuid}/sent"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token

        request.get uri, auth: auth, timeout: 10, =>
        @eventForwarder.once 'message', (@message) =>
          done()

      it 'should send a "subscribe" message', ->
        expect(@message.topic).to.deep.equal 'subscribe'
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
          request:
            type: 'sent'
            uuid: @config.uuid
        }

  xdescribe 'GET /subscribe', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/subscribe"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token

        request.get uri, auth: auth, timeout: 10, =>
        @eventForwarder.once 'message', (@message) =>
          done()

      it 'should send a "subscribe" message', ->
        expect(@message.topic).to.deep.equal 'subscribe'
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
          request: {}
        }

  xdescribe 'GET /authenticate/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/authenticate/#{@config.uuid}"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token

        request.get uri, json: {token: @config.token}, (error) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "identity" message', ->
        expect(@message.topic).to.deep.equal 'identity'
        expect(@message.payload).to.deep.equal {
          request:
            uuid: @config.uuid
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        pathname = "/authenticate/#{@config.uuid}"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token

        request.get uri, (error) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "identity-error" message', ->
        expect(@message.topic).to.deep.equal 'identity-error'
        expect(@message.payload).to.deep.equal {
          error: "Device not found or token not valid"
          request:
            uuid: @config.uuid
        }

  xdescribe 'POST /messages', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.message {devices: ['some-uuid']}, =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "message" message', ->
        expect(@message.topic).to.deep.equal 'message'
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
          request:
            devices: ['some-uuid']
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.message {}, =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "message-error" message', ->
        expect(@message.topic).to.deep.equal 'message-error'
        expect(@message.payload).to.deep.equal {
          fromUuid: "66b2928b-a317-4bc3-893e-245946e9672a"
          error: "Invalid Message Format"
          request: {}
        }

  xdescribe 'POST /data/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/data/#{@config.uuid}"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token

        request.post uri, auth: auth, json: {value: 1}, (error) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "data" message', ->
        expect(@message.topic).to.deep.equal 'data'
        expect(@message.payload).to.deep.equal {
          fromUuid: @config.uuid
          request:
            ipAddress: '127.0.0.1'
            value: 1
        }

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        pathname = "/data/invalid-uuid"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token

        request.post uri, auth: auth, json: {value: 1}, (error) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "data-error" message', ->
        expect(@message.topic).to.deep.equal 'data-error'
        expect(@message.payload).to.deep.equal {
          fromUuid: @config.uuid
          error: "Device not found"
          request:
            ipAddress: '127.0.0.1'
            value: 1
        }

  xdescribe 'GET /data/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/data/#{@config.uuid}"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token

        request.get uri, auth: auth, (error) =>
          @eventForwarder.once 'message', (@message) =>
            done()

      it 'should send a "subscribe" message', ->
        expect(@message.topic).to.deep.equal 'subscribe'
        expect(@message.payload).to.deep.equal {
          fromUuid: @config.uuid
          request:
            type: 'data'
            uuid: @config.uuid
        }
