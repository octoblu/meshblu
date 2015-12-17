_ = require 'lodash'
bcrypt = require 'bcrypt'
moment = require 'moment'
Device = require '../../../lib/models/device'
TestDatabase = require '../../test-database'

describe 'Device', ->
  beforeEach (done) ->
    TestDatabase.open (error, database) =>
      @database = database
      @devices  = @database.devices
      @getGeo = sinon.stub().yields null, {}
      @clearCache = sinon.stub().yields null
      @cacheDevice = sinon.stub()
      @findCachedDevice = sinon.stub().yields null
      @config = token: 'totally-secret-yo'
      @redis =
        get: sinon.stub()
        set: sinon.stub()
        del: sinon.stub()
        exists: sinon.stub()
        setex: sinon.stub()

      @redis.get.yields null
      @redis.setex.yields null

      @dependencies =
        database: @database
        getGeo: @getGeo
        clearCache: @clearCache
        config: @config
        redis: @redis
        cacheDevice: @cacheDevice
        findCachedDevice: @findCachedDevice

      @hashedToken = 'qe4NSaR3wrM6c2Q6uE6diz23ZXHyXUE2u/zJ9rvGE5A='
      done error

  describe '->addGeo', ->
    describe 'when a device has an ipAddress', ->
      beforeEach (done) ->
        @dependencies.getGeo = sinon.stub().yields null, {city: 'smallville'}
        @sut = new Device ipAddress: '127.0.0.1', @dependencies
        @sut.addGeo done

      it 'should call getGeo with the ipAddress', ->
        expect(@dependencies.getGeo).to.have.been.calledWith '127.0.0.1'

      it 'should set the getGeo response on attributes', ->
        expect(@sut.attributes.geo).to.deep.equal {city: 'smallville'}

    describe 'when a device has no ipAddress', ->
      beforeEach (done) ->
        @dependencies.getGeo = sinon.spy()
        @sut = new Device {}, @dependencies
        @sut.addGeo done

      it 'should not call getGeo', ->
        expect(@dependencies.getGeo).not.to.have.been.called

  describe '->addHashedToken', ->
    describe 'when a device exists', ->
      beforeEach (done) ->
        @uuid = 'd17f2411-6465-4a02-b658-6b5c992fb7b2'
        @attributes = {uuid: @uuid, name: 'Cherokee', token : bcrypt.hashSync('cool-token', 8)}
        @devices.insert @attributes, done

      describe 'when the device has an unhashed token', ->
        beforeEach (done) ->
          @sut = new Device uuid: @uuid, token: 'new-token', @dependencies
          @sut.addHashedToken(done)

        it 'should hash the token', ->
          expect(bcrypt.compareSync('new-token', @sut.attributes.token)).to.be.true

      describe 'when the device has no token', ->
        beforeEach (done) ->
          @sut = new Device uuid: @uuid, @dependencies
          @sut.addHashedToken(done)

        it 'should not modify the token', ->
          expect(@sut.token).not.to.exist

      describe 'when instantiated with the hashed token', ->
        beforeEach (done) ->
          @sut = new Device @attributes, @dependencies
          @sut.addHashedToken done

        it 'should not rehash the token', ->
          expect(@sut.attributes.token).to.equal @attributes.token

  describe '->addOnlineSince', ->
    describe 'when a device exists with online', ->
      beforeEach (done) ->
        @uuid = 'dab71557-c8a4-45d9-95ae-8dfd963a2661'
        @onlineSince = new Date(1422484953078)
        @attributes = {uuid: @uuid, online: true, onlineSince: @onlineSince}
        @devices.insert @attributes, done

      describe 'when set online true', ->
        beforeEach (done) ->
          @sut = new Device uuid: @uuid, online: true, @dependencies
          @sut.addOnlineSince done

        it 'should not update onlineSince', ->
          expect(@sut.attributes.onlineSince).not.to.exist

  describe '->fetch', ->
    describe "when a device doesn't exist", ->
      beforeEach (done) ->
        @sut = new Device {}, @dependencies
        @sut.fetch (@error) => done()

      it 'should respond with an error', ->
        expect(@error).to.exist
        expect(@error.message).to.equal 'Device not found'

    describe 'when a device exists', ->
      beforeEach (done) ->
        @uuid = 'b3da16bf-8397-403c-a520-cfb5f6bac798'
        @devices.insert uuid: @uuid, name: 'hahahaha', done

      beforeEach (done) ->
        @sut = new Device uuid: @uuid, @dependencies
        @sut.fetch (@error, @device) => done()

      it 'should respond with the device', ->
        expect(@device.name).to.equal 'hahahaha'

      it 'should respond with no error', ->
        expect(@error).not.to.exist

  describe '->generateToken', ->
    describe 'when generateToken is injected', ->
      beforeEach ->
        @dependencies.generateToken = sinon.spy()
        @sut = new Device {}, @dependencies

      it 'should call generateToken', ->
        @sut.generateToken()
        expect(@dependencies.generateToken).to.have.been.called

  describe '->sanitize', ->
    describe 'when update is called with one good and one bad param', ->
      beforeEach ->
        @sut = new Device {}, @dependencies
        @result = @sut.sanitize name: 'guile', '$natto': 'fermented soybeans'

      it 'should strip the bad params', ->
        expect(@result['$natto']).to.not.exist

      it 'should leave the good param', ->
        expect(@result.name).to.equal 'guile'

    describe 'when update is called with a nested bad param', ->
      beforeEach ->
        @sut = new Device {}, @dependencies
        @result = @sut.sanitize name: 'guile', foo: {'$natto': 'fermented soybeans'}

      it 'should strip the nested bad param', ->
        expect(@result.foo).to.deep.equal {}

      it 'should leave the good param', ->
        expect(@result.name).to.equal 'guile'

    describe 'when update is called with a bad param nested in an object in an array', ->
      beforeEach ->
        @sut = new Device {}, @dependencies
        @result = @sut.sanitize name: 'guile', foo: [{'$natto': 'fermented soybeans'}]

      it 'should strip the offending param', ->
        expect(@result.foo).to.deep.equal [{}]

      it 'should keep the good param', ->
        expect(@result.name).to.equal 'guile'

  describe '->save', ->
    describe 'when a device is saved', ->
      beforeEach (done) ->
        @uuid = '66e20044-7262-4c26-84f0-c2c00fa02465'
        @devices.insert {uuid: @uuid}, done

      beforeEach (done) ->
        @getGeo = sinon.stub().yields null, {city: 'phoenix'}
        @dependencies.getGeo = @getGeo
        @sut = new Device(uuid: @uuid, @dependencies)
        @sut.set name: 'VW bug', online: true, ipAddress: '192.168.1.1'
        @sut.save done

      beforeEach (done) ->
        @devices.findOne {uuid: @uuid}, (error, @device) => done()

      it 'should update the record in devices', ->
        expect(@device.name).to.equal 'VW bug'

      it 'should set geo', ->
        expect(@device.geo).to.exist

      it 'should set geo with city', ->
        expect(@device.geo.city).to.equal 'phoenix'

      it 'should set onlineSince', ->
        expect(@device.onlineSince.getTime()).to.be.closeTo moment().utc().valueOf(), 1000

    describe 'when two devices exist', ->
      beforeEach (done) ->
        @uuid1 = '8172bd75-905f-409e-91d7-121ac0456229'
        @devices.insert {uuid: @uuid1}, done

      beforeEach (done) ->
        @uuid2 = '190f8795-cc33-46d4-834e-f6b91920af77'
        @devices.insert {uuid: @uuid2}, done

      describe 'when first device is modified', ->
        beforeEach (done) ->
          @sut = new Device uuid: @uuid1, foo: 'bar', @dependencies
          @sut.save done

        it 'should update the correct device, because this would never happen in real life', (done) ->
          @devices.findOne {uuid: @uuid1}, (error, device) =>
            return done error if error?
            expect(device.foo).to.equal 'bar'
            done()

        it 'should update the correct device, because this would never happen in real life', (done) ->
          @devices.findOne {uuid: @uuid2}, (error, device) =>
            return done error if error?
            expect(device.foo).to.not.exist
            done()

      describe 'when second device is modified', ->
        beforeEach (done) ->
          @sut = new Device uuid: @uuid2, foo: 'bar', @dependencies
          @sut.save done

        it 'should not update the first device', (done) ->
          @devices.findOne {uuid: @uuid1}, (error, device) =>
            return done error if error?
            expect(device.foo).to.not.exist
            done()

        it 'should update second device', (done) ->
          @devices.findOne {uuid: @uuid2}, (error, device) =>
            return done error if error?
            expect(device.foo).to.equal 'bar'
            done()

  describe '->set', ->
    describe 'when called with a new name', ->
      beforeEach ->
        @sut = new Device name: 'first', @dependencies
        @sut.set name: 'second'

      it 'should update the name', ->
        expect(@sut.attributes.name).to.equal 'second'

    describe 'when set is called disallowed keys', ->
      beforeEach ->
        @sut = new Device {}, @dependencies
        @sut.set $$hashKey: true

      it 'should remove keys beginning with $', ->
        expect(@sut.attributes.$$hashKey).to.not.exist

    describe 'when called with an online of "false"', ->
      beforeEach ->
        @sut = new Device {}, @dependencies
        @sut.set online: 'false'

      it 'should set online to true, cause strings is truthy, yo', ->
        expect(@sut.attributes.online).to.be.true

    describe 'when set is called with an online of false', ->
      beforeEach ->
        @sut = new Device {}, @dependencies
        @sut.set online: false

      it 'should set online to false', ->
        expect(@sut.attributes.online).to.be.false

    describe 'when set doesnt mention online', ->
      beforeEach ->
        @sut = new Device {}, @dependencies
        @sut.set name: 'george'

      it 'should leave online alone', ->
        expect(@sut.attributes.online).to.not.exist

  describe '->storeToken', ->
    describe 'when a device exists', ->
      beforeEach (done) ->
        @uuid = '50805aa3-a88b-4a67-836b-4752e318c979'
        @devices.insert uuid: @uuid, done

      beforeEach ->
        @sut = new Device uuid: @uuid, @dependencies

      describe 'when called with token mystery-token', ->
        beforeEach (done) ->
          @sut.storeToken 'mystery-token', (error) =>
            return done error if error
            @sut.fetch (error, attributes) =>
              @updatedDevice = attributes
              @token = @updatedDevice.meshblu?.tokens?[@hashedToken]
              done(error)


        it 'should hash the token and add it to the attributes', ->
          expect(@updatedDevice.meshblu?.tokens).to.include.keys @hashedToken

        it 'should add a timestamp to the token', ->
          expect(@token.createdAt?.getTime()).to.be.closeTo Date.now(), 1000

        it 'should store the token in the database', (done) ->
          @devices.findOne uuid: @uuid, (error, device) =>
            return done error if error?
            token = @updatedDevice.meshblu?.tokens?[@hashedToken]
            expect(token).to.exist
            done()

  describe '->generateAndStoreTokenInCache', ->
    describe 'when called and it yields a token', ->
      beforeEach (done) ->
        @sut = new Device uuid: @uuid, @dependencies
        @sut.generateToken = sinon.stub().returns 'cheeseburger'
        @sut._hashToken = sinon.stub().yields null, 'this-is-totally-a-secret'
        @sut._storeTokenInCache = sinon.stub().yields null
        @sut.generateAndStoreTokenInCache (@error, @token) => done()
      it 'should call _storeTokenInCache', ->
        expect(@sut._storeTokenInCache).to.have.been.calledWith 'this-is-totally-a-secret'
      it 'should have a token', ->
        expect(@token).to.deep.equal 'cheeseburger'

    describe 'when called and it yields a different token', ->
      beforeEach (done) ->
        @sut = new Device uuid: @uuid, @dependencies
        @sut.generateToken = sinon.stub().returns 'california burger'
        @sut._hashToken = sinon.stub().yields null, 'this-is-totally-a-different-secret'
        @sut._storeTokenInCache = sinon.stub().yields null
        @sut.generateAndStoreTokenInCache (@error, @token) => done()

      it 'should call _storeTokenInCache', ->
        expect(@sut._storeTokenInCache).to.have.been.calledWith 'this-is-totally-a-different-secret'
      it 'should have a token', ->
        expect(@token).to.deep.equal 'california burger'

  describe '->revokeToken', ->
    beforeEach (done) ->
      @uuid = '50805aa3-a88b-4a67-836b-4752e318c979'
      @devices.insert
        uuid: @uuid,
        meshblu:
          tokens:
            'qe4NSaR3wrM6c2Q6uE6diz23ZXHyXUE2u/zJ9rvGE5A=': {}
      , done

    describe 'when a token already exists', ->
      beforeEach (done) ->
        @sut = new Device uuid: @uuid, @dependencies
        @sut.revokeToken 'mystery-token', done

      it 'should remove the token from the device', (done) ->
        @devices.findOne uuid: @uuid, (error, device) =>
          return done error if error?
          expect(device.meshblu?.tokens).not.to.include.keys @hashedToken
          done()

  describe '->verifyToken', ->
    beforeEach ->
      @uuid = '50805aa3-a88b-4a67-836b-4752e318c979';

    describe 'when using the og token', ->
      beforeEach (done) ->
        @token = 'mushrooms'
        @devices.insert uuid: @uuid, =>
          @device = new Device {uuid: @uuid, token: @token}, @dependencies
          @device.save done

      beforeEach (done) ->
        @sut = new Device uuid: @uuid, @dependencies
        @sut._isTokenInBlacklist = sinon.stub().yields null, false
        @sut._verifyTokenInCache = sinon.stub().yields null, false
        @sut.verifyToken 'mushrooms', (error, @verified) => done()

      it 'should be verified', ->
        expect(@verified).to.be.true

    describe 'when using a new token', ->
      beforeEach (done) ->
        @devices.insert
          uuid: @uuid,
          meshblu:
            tokens:
              'qe4NSaR3wrM6c2Q6uE6diz23ZXHyXUE2u/zJ9rvGE5A=': {}
        , done

      beforeEach (done) ->
        @sut = new Device uuid: @uuid, @dependencies
        @sut._isTokenInBlacklist = sinon.stub().yields null, false
        @sut._verifyTokenInCache = sinon.stub().yields null, false
        @sut.verifyToken 'mystery-token', (error, @verified) => done()

      it 'should be verified', ->
        expect(@verified).to.be.true

  describe '->verifySessionToken', ->
    beforeEach (done) ->
      @uuid = '50805aa3-a88b-4a67-836b-4752e318c979'
      @devices.insert
        uuid: @uuid,
        meshblu:
          tokens:
            'qe4NSaR3wrM6c2Q6uE6diz23ZXHyXUE2u/zJ9rvGE5A=': {}
      , done

    describe 'when a token is valid', ->
      beforeEach (done) ->
        @sut = new Device uuid: @uuid, @dependencies
        @sut.verifySessionToken 'mystery-token', (error, @verified) => done()

      it 'should be verified', ->
        expect(@verified).to.be.true

    describe 'when a token is invalid', ->
      beforeEach (done) ->
        @sut = new Device uuid: @uuid, @dependencies
        @sut.verifySessionToken 'mystery-tolkein', (error, @verified) => done()

      it 'should not be verified', ->
        expect(@verified).to.be.false

  describe '->update', ->
    describe 'when a device is saved', ->
      beforeEach (done) ->
        @devices.insert {uuid: 'my-device'}, done

      beforeEach (done) ->
        @getGeo = sinon.stub().yields null, {city: 'phoenix'}
        @dependencies.getGeo = @getGeo
        @sut = new Device(uuid: 'my-device', @dependencies)
        @sut.set name: 'VW bug', online: true, ipAddress: '192.168.1.1', pigeonCount: 3
        @sut.save done

      describe 'when called a normal update query', ->
        beforeEach (done) ->
          @sut.update uuid: 'my-device', name: 'Jetta', done

        it 'should update the record', (done) ->
          @devices.findOne uuid: 'my-device', (error, device) =>
            return done error if error?
            expect(device.name).to.equal 'Jetta'
            done()

      describe 'when called with an increment operator', ->
        beforeEach ->
          @sut.update $inc: {pigeonCount: 1}

        it 'should increment the pigeon count', (done) ->
          @devices.findOne uuid: 'my-device', (error, device) =>
            return done error if error?
            expect(device.pigeonCount).to.equal 4
            done()

  describe '-> _clearTokenCache', ->
    describe 'when redis client is not available', ->
      beforeEach ->
        @dependencies.redis = {}
        @sut = new Device uuid: 'a-uuid', @dependencies
        @sut._clearTokenCache (@error, @result) =>

      it 'should return false', ->
        expect(@result).to.be.false

    describe 'when redis client is available', ->
      beforeEach (done) ->
        @sut = new Device uuid: 'a-uuid', @dependencies
        @sut._clearTokenCache (@error, @result) => done()
        @redis.del.yield null, 1

      it 'should return the result of del', ->
        expect(@result).to.equal 1

      it 'should call redis.del', ->
        expect(@redis.del).to.have.been.calledWith 'tokens:a-uuid'

  describe '-> _storeTokenInCache', ->
    describe 'when redis client is not available', ->
      beforeEach ->
        @dependencies.redis = {}
        @sut = new Device uuid: 'a-uuid', @dependencies
        @sut._storeTokenInCache 'foo', (@error, @result) =>

      it 'should return false', ->
        expect(@result).to.be.false

    describe 'when redis client is available', ->
      beforeEach (done) ->
        @sut = new Device uuid: 'a-uuid', @dependencies
        @sut._storeTokenInCache 'foo', (@error) => done()
        @redis.set.yield null, 'OK'

      it 'should call redis.set', ->
        expect(@redis.set).to.have.been.calledWith 'meshblu-token-cache:a-uuid:foo', ''

  describe '-> removeTokenFromCache', ->
    describe 'when redis client is not available', ->
      beforeEach ->
        @dependencies.redis = {}
        @sut = new Device uuid: 'a-uuid', @dependencies
        @sut.removeTokenFromCache 'foo', (@error, @result) =>

      it 'should return false', ->
        expect(@result).to.be.false

    describe 'when redis client is available', ->
      beforeEach (done) ->
        @sut = new Device uuid: 'a-uuid', @dependencies
        @sut._hashToken = sinon.stub().yields null, 'hashed-foo'
        @sut.removeTokenFromCache 'foo', (@error, @result) => done()
        @redis.del.yield null

      it 'should call redis.srem', ->
        expect(@redis.del).to.have.been.calledWith 'meshblu-token-cache:a-uuid:hashed-foo'

  describe '-> _storeInvalidTokenInBlacklist', ->
    describe 'when redis client is not available', ->
      beforeEach ->
        @dependencies.redis = {}
        @sut = new Device uuid: 'a-uuid', @dependencies
        @sut._storeInvalidTokenInBlacklist 'foo', (@error, @result) =>

      it 'should return false', ->
        expect(@result).to.be.false

    describe 'when redis client is available', ->
      beforeEach (done) ->
        @sut = new Device uuid: 'a-uuid', @dependencies
        @sut._storeInvalidTokenInBlacklist 'foo', (@error, @result) => done()
        @redis.set.yield null

      it 'should call redis.set', ->
        expect(@redis.set).to.have.been.calledWith 'meshblu-token-black-list:a-uuid:foo'

  describe '-> _verifyTokenInCache', ->
    describe 'when redis client is not available', ->
      beforeEach ->
        @dependencies.redis = {}
        @sut = new Device uuid: 'a-uuid', @dependencies
        @sut._verifyTokenInCache 'foo', (@error, @result) =>

      it 'should return false', ->
        expect(@result).to.be.false

    describe 'when redis client is available', ->
      describe 'when the member is available in the set', ->
        beforeEach (done) ->
          @sut = new Device uuid: 'a-uuid', @dependencies
          @sut._verifyTokenInCache 'foo', (@error, @result) => done()
          @redis.exists.yield null, 1

        it 'should return the result of exists', ->
          expect(@result).to.equal 1

        it 'should call redis.exists', ->
          expect(@redis.exists).to.have.been.calledWith 'meshblu-token-cache:a-uuid:DnN1cXdfiInpeLs9VjOXM+C/1ow2nGv46TGrevRN3a0='

      describe 'when the member is not available in the set', ->
        beforeEach (done) ->
          @sut = new Device uuid: 'a-uuid', @dependencies
          @sut._verifyTokenInCache 'foo', (@error, @result) => done @error
          @redis.exists.yield null, 0

        it 'should return the result of exists', ->
          expect(@result).to.equal 0

        it 'should call redis.exists', ->
          expect(@redis.exists).to.have.been.calledWith 'meshblu-token-cache:a-uuid:DnN1cXdfiInpeLs9VjOXM+C/1ow2nGv46TGrevRN3a0='

  describe '-> _isTokenInBlacklist', ->
    describe 'when redis client is not available', ->
      beforeEach ->
        @dependencies.redis = {}
        @sut = new Device uuid: 'a-uuid', @dependencies
        @sut._isTokenInBlacklist 'foo', (@error, @result) =>

      it 'should return false', ->
        expect(@result).to.be.false

    describe 'when redis client is available', ->
      describe 'when the member is available in the set', ->
        beforeEach (done) ->
          @sut = new Device uuid: 'a-uuid', @dependencies
          @sut._isTokenInBlacklist 'foo', (@error, @result) => done()
          @redis.exists.yield null, 1

        it 'should return the result of exists', ->
          expect(@result).to.equal 1

        it 'should call redis.exists', ->
          expect(@redis.exists).to.have.been.calledWith 'meshblu-token-black-list:a-uuid:foo'

      describe 'when the member is not available in the set', ->
        beforeEach (done) ->
          @sut = new Device uuid: 'a-uuid', @dependencies
          @sut._isTokenInBlacklist 'foo', (@error, @result) => done()
          @redis.exists.yield null, 0

        it 'should return the result of exists', ->
          expect(@result).to.equal 0

        it 'should call redis.exists', ->
          expect(@redis.exists).to.have.been.calledWith 'meshblu-token-black-list:a-uuid:foo'

  describe '-> resetToken', ->
    beforeEach ->
      @sut = new Device uuid: 'a-uuid', @dependencies
      sinon.stub(@sut, 'save')

    describe 'when it works', ->
      beforeEach ->
        @sut.resetToken (@error, @token) =>
        @sut.save.yield null

      it 'should not have an error', ->
        expect(@error).not.to.exist

      it 'should have a token', ->
        expect(@token).to.exist

      it 'should call set the token attribute', ->
        expect(@sut.attributes.token).to.exist

    describe 'when it does not work', ->
      beforeEach ->
        @sut.resetToken (@error, @token) =>
        @sut.save.yield new Error 'something wrong'

      it 'should have an error', ->
        expect(@error).to.exist

      it 'should not have a token', ->
        expect(@token).not.to.exist

  describe '->validate', ->
    describe 'when created with a different uuid', ->
      beforeEach (done) ->
        @sut = new Device uuid: 'f853214e-69b9-4ca7-a11e-7ee7b1f8f5be', @dependencies
        @sut.set uuid: 'different-uuid'
        @sut.validate (@error, @result) =>
          done()

      it 'should yield false', ->
        expect(@result).to.be.false

      it 'should have an error', ->
        expect(@error).to.exist
        expect(@error.message).to.equal 'Cannot modify uuid'

    describe 'when updated with the same uuid', ->
      beforeEach (done) ->
        @uuid = '758a080b-fd29-4413-8339-53cc5de3a649'
        @sut = new Device uuid: @uuid, @dependencies
        @sut.set uuid: @uuid
        @sut.validate (@error, @result) =>
          done()

      it 'should yield true', ->
        expect(@result).to.be.true

      it 'should not yield an error', ->
        expect(@error).to.not.exist
