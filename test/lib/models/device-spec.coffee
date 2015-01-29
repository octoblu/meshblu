bcrypt = require 'bcrypt'
moment = require 'moment'
async  = require 'async'
Device = require '../../../lib/models/device'
TestDatabase = require '../../test-database'

describe 'Device', ->
  beforeEach (done) ->
    TestDatabase.open (error, database) =>
      @database = database
      @devices  = @database.devices
      @getGeo = sinon.stub().yields null, {}
      @dependencies = {database: @database, getGeo: @getGeo}
      done error

  describe '->fetch', ->
    describe "when a device doesn't exist", ->
      beforeEach (done) ->
        @sut = new Device
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

  describe '->sanitize', ->
    describe 'when update is called with one good and one bad param', ->
      beforeEach ->
        @sut = new Device
        @result = @sut.sanitize name: 'guile', '$natto': 'fermented soybeans'

      it 'should strip the bad params', ->
        expect(@result['$natto']).to.not.exist

      it 'should leave the good param', ->
        expect(@result.name).to.equal 'guile'

    describe 'when update is called with a nested bad param', ->
      beforeEach ->
        @sut = new Device
        @result = @sut.sanitize name: 'guile', foo: {'$natto': 'fermented soybeans'}

      it 'should strip the nested bad param', ->
        expect(@result.foo).to.deep.equal {}

      it 'should leave the good param', ->
        expect(@result.name).to.equal 'guile'

    describe 'when update is called with a bad param nested in an object in an array', ->
      beforeEach ->
        @sut = new Device
        @result = @sut.sanitize name: 'guile', foo: [{'$natto': 'fermented soybeans'}]

      it 'should strip the offending param', ->
        expect(@result.foo).to.deep.equal [{}]

      it 'should keep the good param', ->
        expect(@result.name).to.equal 'guile'

  describe '->save', ->
    describe 'when a device is saved', ->
      beforeEach (done) ->
        @uuid = '66e20044-7262-4c26-84f0-c2c00fa02465';
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

      it 'should set the timestamp', ->
        time = @device.timestamp.getTime()
        expect(time).to.be.closeTo Date.now(), 1000

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
        @sut = new Device name: 'first'
        @sut.set name: 'second'

      it 'should update the name', ->
        expect(@sut.attributes.name).to.equal 'second'

    describe 'when set is called disallowed keys', ->
      beforeEach ->
        @sut = new Device
        @sut.set $$hashKey: true

      it 'should remove keys beginning with $', ->
        expect(@sut.attributes.$$hashKey).to.not.exist

    describe 'when called with an online of "false"', ->
      beforeEach ->
        @sut = new Device
        @sut.set online: 'false'

      it 'should set online to true, cause strings is truthy, yo', ->
        expect(@sut.attributes.online).to.be.true

    describe 'when set is called with an online of false', ->
      beforeEach ->
        @sut = new Device
        @sut.set online: false

      it 'should set online to false', ->
        expect(@sut.attributes.online).to.be.false

    describe 'when set doesnt mention online', ->
      beforeEach ->
        @sut = new Device
        @sut.set name: 'george'

      it 'should leave online alone', ->
        expect(@sut.attributes.online).to.not.exist

  describe '->validate', ->
    describe 'when created with a different uuid', ->
      beforeEach ->
        @sut = new Device uuid: 'f853214e-69b9-4ca7-a11e-7ee7b1f8f5be'
        @sut.set uuid: 'different-uuid'
        @result = @sut.validate()

      it 'should return false', ->
        expect(@result).to.be.false

      it 'should set error on the device', ->
        expect(@sut.error).to.exist
        expect(@sut.error.message).to.equal 'Cannot modify uuid'

    describe 'when updated with the same uuid', ->
      beforeEach ->
        @uuid = '758a080b-fd29-4413-8339-53cc5de3a649'
        @sut = new Device uuid: @uuid
        @sut.set uuid: @uuid
        @result = @sut.validate()

      it 'should return true', ->
        expect(@result).to.be.true

      it 'should not set an error on the device', ->
        expect(@sut.error).to.not.exist

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



