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
      @dependencies = {database: @database, getGeo: @getGeo}
      done error

  describe 'when a device already exists', ->
    beforeEach (done) ->
      @uuid = '66e20044-7262-4c26-84f0-c2c00fa02465';
      @devices.insert {uuid: @uuid}, done
      @sut = new Device(uuid: @uuid, @dependencies)

    describe 'when a device is saved', ->
      beforeEach (done) ->
        @getGeo = sinon.stub().yields null, {city: 'phoenix'}
        @dependencies.getGeo = @getGeo
        @sut = new Device(uuid: @uuid, @dependencies)
        @sut.set name: 'VW bug', ipAddress: '192.168.1.1'
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

      it 'should call getGeo', ->
        expect(@getGeo).to.have.been.called

    describe 'when a device is saved with a different name', ->
      beforeEach (done) ->
        @sut.set name: 'Corvette Stingray'
        @sut.save done

      it 'should update the record in devices', (done) ->
        @devices.findOne {uuid: @uuid}, (error, device) =>
          expect(device.name).to.equal 'Corvette Stingray'
          done()

    describe 'when created with a different uuid', ->
      beforeEach (done) ->
        @sut = new Device(uuid: 'wrong-uuid', @dependencies)
        @sut.set name: 'Corvette Stingray'
        @sut.save (@error) => done()

      it 'should respond with an error', ->
        expect(@error).to.exist
        expect(@error.message).to.equal 'Device not found'

    describe 'when updated with a different uuid', ->
      beforeEach (done) ->
        @sut.set uuid: 'different-uuid'
        @sut.save (@error) => done()

      it 'should respond with an error', ->
        expect(@error).to.exist
        expect(@error.message).to.equal 'Cannot modify uuid'

    describe 'when updated with the same uuid', ->
      beforeEach (done) ->
        @sut.set uuid: @uuid
        @sut.save (@error) => done()

      it 'should not respond with an error', ->
        expect(@error).to.not.exist

    describe 'when a device is instantiated with a name', ->
      beforeEach ->
        @sut = new Device {uuid: @uuid, name: 'Daf'}, @dependencies

      describe 'when the device is saved', ->
        beforeEach (done) ->
          @sut.save done

        it 'should update the device record with the name', (done) ->
          @devices.findOne uuid: @uuid, (error, device) =>
            done error if error?
            expect(device.name).to.equal 'Daf'
            done()

      describe 'when a set is called and the device is saved', ->
        beforeEach (done) ->
          @sut.set foo: 'bar'
          @sut.save done

        it 'should store the name', (done) ->
          @devices.findOne uuid: @uuid, (error, device) =>
            done error if error?
            expect(device.name).to.equal 'Daf'
            done()

    describe 'when saved with a token', ->
      beforeEach (done) ->
        @attributes = {uuid: @uuid, name: 'Cherokee', token : 'plain-text-token'}
        @sut = new Device @attributes, @dependencies
        @sut.save(done)

      it 'should update a hash of the token', (done) ->
        @database.devices.findOne { uuid: @uuid }, (error, device) =>
          return done error if error?
          expect(bcrypt.compareSync(@attributes.token, device.token)).to.be.true
          done()

  describe 'when a device with a token exists', ->
    beforeEach (done) ->
      @uuid = '028ca74a-7e64-47fd-b55a-8abcd0c09dae'
      @hashedToken = bcrypt.hashSync 'cool-token', 8
      @devices.insert {uuid: @uuid, token: @hashedToken}, done

    describe 'when the device is saved with no new token', ->
      beforeEach (done) ->
        @sut = new Device uuid: @uuid, @dependencies
        @sut.save done

      it 'should not modify the token', (done) ->
        @devices.findOne uuid: @uuid, (error, device) =>
          return done error if error?
          expect(device.token).to.equal @hashedToken
          done()

    describe 'when instantiated with the hashed token', ->
      beforeEach (done) ->
        @sut = new Device uuid: @uuid, token: @hashedToken, @dependencies
        @sut.save done

      it 'should not rehash the token', (done) ->
        @devices.findOne uuid: @uuid, (error, device) =>
          return done error if error?
          expect(device.token).to.equal @hashedToken
          done()

  describe 'when a device exists with online', ->
    beforeEach (done) ->
      @uuid = 'dab71557-c8a4-45d9-95ae-8dfd963a2661'
      @onlineSince = new Date(1422484953078)
      @attributes = {uuid: @uuid, online: true, onlineSince: @onlineSince}
      @devices.insert @attributes, done

    describe 'when we save it with online true', ->
      beforeEach (done) ->
        @sut = new Device uuid: @uuid, online: true, @dependencies
        @sut.save done

      it 'should not update onlineSince', (done) ->
        @devices.findOne uuid: @uuid, (error, device) =>
          return done error if error?
          expect(device.onlineSince).to.equal @onlineSince
          done()

  describe 'when set is called with an online of "false"', ->
    beforeEach ->
      @sut = new Device
      @sut.set online: 'false'

    it 'should set online to true, cause strings is truthy, yo', ->
      expect(@sut.attributes.online).to.be.true

  describe 'when set is called disallowed keys', ->
    beforeEach ->
      @sut = new Device
      @sut.set $$hashKey: true

    it 'should remove keys beginning with $', ->
      expect(@sut.attributes.$$hashKey).to.not.exist

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

    it 'should not set onlineSince', ->
      expect(@sut.attributes.onlineSince).to.not.exist

