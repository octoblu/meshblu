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
    @conx = meshblu.createConnection @config

    @conx.on 'ready', => done()
    @conx.on 'notReady', done

  afterEach ->
    @conx.removeAllListeners()

  it 'should get here', ->
    expect(true).to.be.true

  describe 'GET /devices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.devices {}, (@error, @result)=>
          done()

      it 'should not yield an error', ->
        expect(@error).to.not.exist

      it 'should yield devices', ->
        expect(@result.devices.length > 0).to.be.true

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

  describe 'GET /devices/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/devices/#{@config.uuid}"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.get uri, auth: auth, json: true, (@error, @response, @body) =>
          done()

      it 'should not yield a error', ->
        expect(@error).to.not.exist

      it 'should have a statusCode of 200', ->
        expect(@response.statusCode).to.equal 200

      it 'should yield a device', ->
        expect(@body.devices[0].uuid).to.deep.equal @config.uuid

      it 'should not yield a token', ->
        expect(@body.devices[0].token).to.not.exist

      it 'should not yield tokens', ->
        expect(@body.devices[0].tokens).to.not.exist

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        pathname = "/devices/invalid-uuid"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.get uri, auth: auth, json: true, (@error, @response, @body) =>
          done()

      it 'should not yield a error', ->
        expect(@error).to.not.exist

      it 'should have a statusCode of 404', ->
        expect(@response.statusCode).to.equal 404

      it 'should yield an empty devices array', ->
        expect(@body.devices).to.be.empty

  describe 'GET /v2/whoami', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.whoami (@error, @device) => done()

      it 'should not yield an error', ->
        expect(@error).to.not.exist

      it 'should yield the correct device with uuid', ->
        expect(@device.uuid).to.deep.equal @config.uuid

  describe 'GET /v2/devices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/v2/devices"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        query = {foo: 'bar'}
        request.get uri, auth: auth, qs: query, json: true, (@error, @response, @body) => done()

      it 'should yield no error', ->
        expect(@error).to.not.exist

      it 'should have a statusCode of 200', ->
        expect(@response.statusCode).to.equal 200

      it 'should yield devices', ->
        expect(@body).to.be.an.array

      it 'should yield devices', ->
        expect(@body[0].uuid).to.exist

  describe.only 'GET /v2/devices/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.device @config.uuid, (@error, @device) => done()

      it 'should not yield an error', ->
        expect(@error).to.not.exist

      it 'should yield a device', ->
        expect(@device.uuid).to.deep.equal @config.uuid

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.device 'invalid-uuid', (@error, @device) => done()

      it 'should yield an error', ->
        expect(@error).to.exist

      it 'should not yield a device', ->
        expect(@device).to.not.exist

    describe 'when called with an x-forwarded-for header', ->
      beforeEach (done) ->
        @meshblu.register discoverAsWhitelist: [@config.uuid], (error, @discovererDevice) =>
          @meshblu.register discoverWhitelist: [@discovererDevice.uuid], (error, @discovereeDevice) =>
            done()

      beforeEach (done) ->
        pathname = "/devices/#{@discovereeDevice.uuid}"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        headers = 'x-forwarded-for': @discovererDevice.uuid

        request.get uri, {auth, headers, json: true}, (@error, @response, @body) => done()

      it 'should not yield a error', ->
        expect(@error).to.not.exist

      it 'should have a statusCode of 200', ->
        expect(@response.statusCode).to.equal 200

      it 'should yield a device', ->
        expect(@body.uuid).to.deep.equal @discoveree.uuid



  describe 'PATCH /v2/devices/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @conx.on 'config', (@device) =>
          done()
        @meshblu.update @config.uuid, foorer: 'bar-awesome', (@error) =>

      it 'should not yield an error', ->
        expect(@error).to.not.exist

      it 'should yield a config event with the updated property', ->
        expect(@device.foorer).to.deep.equal 'bar-awesome'

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.update @config.uuid, {$foo: 'bar'}, (@error) => done()

      it 'should not yield a updated device', ->
        expect(@device).to.not.exist

      it 'should yield an error', ->
        expect(@error).to.exist

  describe 'PUT /v2/devices/:uuid', ->
    describe 'when called with a valid request to delete a property', ->
      beforeEach (done) ->
        @conx.on 'config', (@device) =>
          done()
        @meshblu.updateDangerously @config.uuid, {$unset: {foomer: 'bar-great'}}, (error) =>
          return done error if error?

      it 'should yield a config event without the deleted property', ->
        expect(@device.foomer).to.not.exist

    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @conx.on 'config', (@device) =>
          done()
        @meshblu.updateDangerously @config.uuid, {$set: {fooest: 'awesome-bar'}}, (error) =>
          return done error if error?

      it 'should yield a config event with the updated property', ->
        expect(@device.fooest).to.deep.equal 'awesome-bar'

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.updateDangerously @config.uuid, {$set: { $$cheese: 'awesome-bar'}}, (@error) => done()

      it 'should yield an error', ->
        expect(@error).to.exist

  describe 'GET /localdevices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/localdevices"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.get uri, auth: auth, json: true, (@error, @response, @body) => done()

      it 'should not yield an error', ->
        expect(@error).to.not.exist

      it 'should have a statusCode of 200', ->
        expect(@response.statusCode).to.equal 200

      it 'should yield devices', ->
        expect(@body.devices).not.to.be.empty

      it 'should yield a device with a uuid', ->
        expect(@body.devices[0].uuid).to.exist

      it 'should yield a device without a token', ->
        expect(@body.devices[0].token).to.not.exist

      it 'should yield a device without tokens', ->
        expect(@body.devices[0].tokens).to.not.exist

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        pathname = "localdevices"
        query = uuid: 'invalid-uuid'
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.get uri, auth: auth, qs: query, json: true, (@error, @response, @body) => done()

      it 'should not yield an error', ->
        expect(@error).to.not.exist

      it 'should have a statusCode of 404', ->
        expect(@response.statusCode).to.equal 404

      it 'should have a body', ->
        expect(@body.message).to.deep.equal "Devices not found"

  describe 'GET /unclaimeddevices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/unclaimeddevices"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.get uri, auth: auth, json: true, (@error, @response, @body) => done()

      it 'should not yield an error', ->
        expect(@error).to.not.exist

      it 'should have a statusCode of 200', ->
        expect(@response.statusCode).to.equal 200

      it 'should yield devices', ->
        expect(@body.devices).not.to.be.empty

      it 'should yield a device with a uuid', ->
        expect(@body.devices[0].uuid).to.exist

      it 'should yield a device without a token', ->
        expect(@body.devices[0].token).to.not.exist

      it 'should yield a device without tokens', ->
        expect(@body.devices[0].tokens).to.not.exist

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        pathname = "unclaimeddevices"
        query = uuid: 'invalid-uuid'
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.get uri, auth: auth, qs: query, json: true, (@error, @response, @body) => done()

      it 'should not yield an error', ->
        expect(@error).to.not.exist

      it 'should have a statusCode of 404', ->
        expect(@response.statusCode).to.equal 404

      it 'should have a body', ->
        expect(@body.message).to.deep.equal "Devices not found"

  describe 'PUT /claimdevice/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register configWhitelist: ['*'], (error, device) =>
          return done error if error?
          @device = device
          pathname = "/claimdevice/#{@device.uuid}"
          uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
          auth = user: @config.uuid, pass: @config.token
          request.put uri, auth: auth, json: true, (@error, @response, @body) => done()

      it 'should be not have an error', ->
        expect(@error).to.not.exist

      it 'should have a statusCode of 200', ->
        expect(@response.statusCode).to.equal 200

      it 'should yield a device', ->
        expect(@body.uuid).to.exist

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        pathname = "/claimdevice/invalid-uuid"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.put uri, auth: auth, json: true, (@error, @response, @body) => done()

      it 'should not have error', ->
        expect(@error).to.not.exist

      it 'should have a statusCode of 404', ->
        expect(@response.statusCode).to.equal 400

      it 'should have an in the body', ->
        expect(@body.error).to.deep.equal "Device not found"

  describe 'GET /devices/:uuid/publickey', ->
    describe 'when called with a valid request with no publicKey', ->
      beforeEach (done) ->
        @meshblu.publicKey @config.uuid, (error, @result) => done error

      it 'should yield a result with a publicKey', ->
        expect(@result.publicKey).to.exist

    describe 'when called with a valid request without a publicKey', ->
      beforeEach (done) ->
        @meshblu.register {}, (error, device) =>
          return done error if error?
          @meshblu.publicKey device.uuid, (error, @result) => done error

      it 'should yield a result with a publicKey', ->
        expect(@result.publicKey).to.be.null

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.publicKey 'invalid-uuid', (@error, @result) => done()

      it 'should have an error', ->
        expect(@error).to.be.an.error

      it 'should not have a result', ->
        expect(@result).to.not.exist

  describe 'POST /devices/:uuid/token', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        # Oh hello there, you may be wondering this madness is? Well it makes sure the token is different. Crazily. Sorry bro.
        @meshblu.register configWhitelist: ['*'], (error, device) =>
          return done error if error?
          @conx.subscribe uuid: device.uuid, (error) =>
            @conx.once 'config', (@device) =>
              @conx.once 'config', (@updatedDevice) =>
                done() if @updatedDevice.uuid == @device.uuid
              @meshblu.resetToken device.uuid, (error) =>
                return done error if error?
            @meshblu.update device.uuid, ya: 'sweet'

      it 'should change the token', ->
        expect(@updatedDevice.token).to.not.equal @device.token

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.resetToken 'invalid-uuid', (@error) => done()

      it 'should have an error', ->
        expect(@error).to.exist

  describe 'POST /devices/:uuid/tokens', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register configWhitelist: ['*'], (error, @device) =>
          return done error if error?
          @meshblu.generateAndStoreToken @device.uuid, (error, @updatedDevice) =>
            return done error if error?
            done()

      it 'should have a different token', ->
        expect(@device.token).to.exist
        expect(@updatedDevice.token).to.exist
        expect(@device.token).to.not.deep.equal @updatedDevice.token

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.generateAndStoreToken 'invalid-uuid', (@error, @device) => done()

      it 'should be an error', ->
        expect(@error.message).to.equal "Device not found"

      it 'should not have a device', ->
        expect(@device).to.not.exist

  describe 'DELETE /devices/:uuid/tokens/:token', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register configWhitelist: ['*'], (error, device) =>
          return done error if error?

          @meshblu.generateAndStoreToken device.uuid, (error, @device) =>
            return done error if error?

            @meshblu.revokeToken @device.uuid, @device.token, (error) =>
              return done error if error?
              done()

        it 'should not blow up', ->
          expect(true).to.be.true

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.revokeToken 'invalid-uuid', 'invalid-token', (@error) => done()

      it 'should have an error', ->
        expect(@error).to.exist

  describe 'POST /devices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.register {}, (error, @device) =>
          return done error if error?
          done()

      it 'should create device with uuid and token', ->
        expect(@device.uuid).to.exist
        expect(@device.token).to.exist

      it 'should set an ipAddress', ->
        expect(@device.ipAddress).to.equal '127.0.0.1'

      it 'should set online to false', ->
        expect(@device.online).to.be.false

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.register uuid: 'not-allowed', (@error, @result) =>
          done()

      it 'should have an error', ->
        expect(@error.message).to.deep.equal 'Device not updated'

  describe 'PUT /devices/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/devices/#{@config.uuid}"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.put uri, auth: auth, json: {foomo: 'barmo'},  (error, @response, @body) =>
          return done error if error?
          done()

      it 'should have the correct statusCode', ->
        expect(@response.statusCode).to.equal 200

      it 'should have the correct body', ->
        expect(@body.foomo).to.deep.equal 'barmo'

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        pathname = "/devices/invalid-uuid"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.put uri, auth: auth, json: {foomar: 'barmar'},  (error, @response, @body) =>
          return done error if error?
          done()

      it 'should have the correct statusCode', ->
        expect(@response.statusCode).to.equal 404

      it 'should have the correct body', ->
        expect(@body.message).to.equal 'Device not found'

  describe 'DELETE /devices/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'unregister'
        @meshblu.register {}, (error, device) =>
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
        @meshblu.unregister uuid: 'invalid-uuid', (@error) =>
          done()

      it 'should have an error', ->
        expect(@error.message).to.equal "invalid device to unregister"

  describe 'GET /mydevices', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @meshblu.mydevices {}, (error, @result) =>
          done error if error?
          done()

      it 'should have devices', ->
        expect(@result.devices).to.not.be.empty

      it 'the first device should have a uuid', ->
        expect(_.first(@result.devices).uuid).to.exist

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.mydevices {uuid: 'invalid-uuid'}, (@error, @result) => done()

      it 'should have an error', ->
        expect(@error).to.exist

      it 'should not have a result', ->
        expect(@result).to.not.eixst

  describe 'GET /subscribe/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/subscribe/#{@config.uuid}"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.get uri, auth: auth, timeout: 10, => done()

      it 'should not blow up', ->
        expect(true).to.be.true

  describe 'GET /subscribe/:uuid/broadcast', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/subscribe/#{@config.uuid}/broadcast"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.get uri, auth: auth, timeout: 10, => done()

      it 'should not blow up', ->
        expect(true).to.be.true

  describe 'GET /subscribe/:uuid/received', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/subscribe/#{@config.uuid}/received"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.get uri, auth: auth, timeout: 10, => done()

      it 'should not blow up', ->
        expect(true).to.be.true

  describe 'GET /subscribe/:uuid/sent', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/subscribe/#{@config.uuid}/sent"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.get uri, auth: auth, timeout: 10, => done()

      it 'should not blow up', ->
        expect(true).to.be.true

  describe 'GET /subscribe', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/subscribe"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.get uri, auth: auth, timeout: 10, => done()

      it 'should not blow up', ->
        expect(true).to.be.true

  describe 'GET /authenticate/:uuid', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        pathname = "/authenticate/#{@config.uuid}"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.get uri, json: {token: @config.token}, (error, @response, @body) => done error

      it 'should have the correct statusCode', ->
        expect(@response.statusCode).to.equal 200

      it 'should have the correct uuid', ->
        expect(@body.uuid).to.equal @config.uuid

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        pathname = "/authenticate/#{@config.uuid}"
        uri = url.format protocol: @config.protocol, hostname: @config.server, port: @config.port, pathname: pathname
        auth = user: @config.uuid, pass: @config.token
        request.get uri, (@error, @response, @body) => done()

      it 'should not have an error', ->
        expect(@error).to.not.exist

      it 'have the the correct statusCode', ->
        expect(@response.statusCode).to.equal 404

  describe 'POST /messages', ->
    describe 'when called with a valid request', ->
      beforeEach (done) ->
        @conx.on 'message', (@message) =>
          done() if @message.topic == 'im-awesome'
        @meshblu.message {devices: [@config.uuid], topic: 'im-awesome', payload: 'peter'}, =>

      it 'should have recieve the correct message', ->
        expect(@message.topic).to.equal 'im-awesome'
        expect(@message.devices).to.deep.equal [@config.uuid]
        expect(@message.payload).to.deep.equal 'peter'

    describe 'when called with an invalid request', ->
      beforeEach (done) ->
        @meshblu.message {}, (@error) => done()

      it 'should have an error', ->
        expect(@error).to.exist
