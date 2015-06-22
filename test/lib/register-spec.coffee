_      = require 'lodash'
moment = require 'moment'
TestDatabase = require '../test-database'

describe 'register', ->
  beforeEach (done) ->
    @sut = require '../../lib/register'
    @oldUpdateDevice = sinon.stub()
    TestDatabase.open (error, database) =>
      @database = database
      @devices  = @database.devices

      @dependencies = {database: @database, oldUpdateDevice: @oldUpdateDevice}
      done error

  it 'should be a function', ->
    expect(@sut).to.be.a 'function'

  describe 'when called with no params', ->
    beforeEach (done) ->
      @timestamp = moment().toISOString()
      @oldUpdateDevice.yields null, timestamp: @timestamp
      storeDevice = (@error, @device) => done()
      @sut null, storeDevice, @dependencies

    it 'should return a device', ->
      expect(@device).to.exist

    it 'should create a device', (done) ->
      @database.devices.count {}, (error, count) =>
        return done error if error?
        expect(count).to.equal 1
        done()

    it 'should generate a new uuid', (done) ->
      @database.devices.findOne {}, (error, device) =>
        return done error if error?
        expect(device.uuid).to.exist
        done()

    it 'should generate a new token', ->
      expect(@device.token).to.exist

    it 'should call oldUpdateDevice', ->
      expect(@oldUpdateDevice).to.have.been.called

    it 'should merge in the timestamp from update Device', ->
      expect(@device.timestamp).to.equal @timestamp

    describe 'when called again with no params', ->
      beforeEach (done) ->
        @oldUpdateDevice.yields null, {}
        storeDevice = (error, @newerDevice) => done()
        @sut null, storeDevice, @dependencies

      it 'should create a new device', ->
        expect(@newerDevice).to.exist

      it 'should generate a different token', ->
        expect(@newerDevice.token).to.not.equal @device.token

  describe 'when called with a specific uuid', ->
    beforeEach (done) ->
      @oldUpdateDevice.yields null, {}
      @dependencies.uuid =
        v4: sinon.stub().returns 'some-other-uuid'

      @sut {uuid: 'some-uuid'}, done, @dependencies

    it 'should generate a new uuid for the device', (done) ->
      @devices.findOne uuid: 'some-other-uuid', (error, device) =>
        expect(device).to.exist
        done()

  describe 'when called with an owner id', ->
    beforeEach (done) ->
      @oldUpdateDevice.yields null, {}
      @params = {uuid: 'some-uuid', token: 'token', owner: 'other-uuid'}
      @sut @params, done, @dependencies

    it 'should set the discoverWhitelist to the owners UUID',  ->
      expect(@oldUpdateDevice).to.have.been.calledWith(
        sinon.match.any
        sinon.match
          token: 'token'
          owner: 'other-uuid'
          discoverWhitelist: ['other-uuid']
      )


  describe 'when called without an online', ->
    beforeEach (done) ->
      @oldUpdateDevice.yields null, {}
      @sut {}, done, @dependencies

    it 'should create a device with an online of false', (done) ->
      @devices.findOne {}, (error, device) =>
        expect(device.online).to.be.false
        done()

  describe 'when there is an existing device', ->
    beforeEach (done) ->
      @devices.insert {uuid : 'some-uuid', name: 'Somebody.'}, done

    describe 'trying to create a new device with a different uuid', ->
      beforeEach (done) ->
        @oldUpdateDevice.yields null, {}
        storeDevice = (@error, @device) => done()
        @sut {uuid: 'some-other-uuid'}, storeDevice, @dependencies

      it 'it create a second device', (done) ->
        @database.devices.count {}, (error, count) =>
          return done error if error?
          expect(count).to.equal 2
          done()

  describe 'when called with just a name', ->
    beforeEach (done) ->
      @oldUpdateDevice.yields null, {}
      storeDevice = (error, @device) => done()
      @params = {name: 'bobby'}
      @originalParams = _.cloneDeep @params
      @sut @params, storeDevice, @dependencies

    it 'should not mutate the params', ->
      expect(@params).to.deep.equal @originalParams
