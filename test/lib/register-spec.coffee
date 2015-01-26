_      = require 'lodash'
moment = require 'moment'
TestDatabase = require '../test-database'

describe 'register', ->
  beforeEach (done) ->
    @sut = require '../../lib/register'
    @updateDevice = sinon.stub()
    TestDatabase.open (error, database) =>
      @database = database
      @devices  = @database.devices

      @dependencies = {database: @database, updateDevice: @updateDevice}
      done error

  it 'should be a function', ->
    expect(@sut).to.be.a 'function'

  describe 'when called with no params', ->
    beforeEach (done) ->
      @timestamp = moment().toISOString()
      @updateDevice.yields null, timestamp: @timestamp
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

    it 'should call updateDevice', ->
      expect(@updateDevice).to.have.been.called

    it 'should merge in the timestamp from update Device', ->
      expect(@device.timestamp).to.equal @timestamp

    describe 'when called again with no params', ->
      beforeEach (done) ->
        @updateDevice.yields null, {}
        storeDevice = (error, @newerDevice) => done()
        @sut null, storeDevice, @dependencies

      it 'should create a new device', ->
        expect(@newerDevice).to.exist

      it 'should generate a different token', ->
        expect(@newerDevice.token).to.not.equal @device.token

  describe 'when called with a specific uuid', ->
    beforeEach (done) ->
      @updateDevice.yields null, {}
      @sut {uuid: 'some-uuid'}, done, @dependencies

    it 'should create a device with that uuid', (done) ->
      @devices.findOne uuid: 'some-uuid', (error, device) =>
        expect(device).to.exist
        done()

  describe 'when called with a specific token', ->
    beforeEach (done) ->
      @updateDevice.yields null, {}
      storeDevice = (error, @device) => done()
      @sut {token: 'mah-secrets'}, storeDevice, @dependencies

    it 'should call update device with that token', ->
      @devices.findOne (error, device) =>
        expect(@updateDevice).to.be.calledWith device.uuid, {token: 'mah-secrets', uuid: device.uuid}

  describe 'when called with an owner id', ->
    beforeEach (done) ->
      @updateDevice.yields null, {}
      @params = {uuid: 'some-uuid', token: 'token', owner: 'other-uuid'}
      @sut @params, done, @dependencies

    it 'should set the discoverWhitelist to the owners UUID',  ->
      expect(@updateDevice).to.have.been.calledWith 'some-uuid', {
        uuid:  'some-uuid'
        token: 'token'
        owner: 'other-uuid'
        discoverWhitelist: ['other-uuid']
      }


  describe 'when called without an online', ->
    beforeEach (done) ->
      @updateDevice.yields null, {}
      @sut {}, done, @dependencies

    it 'should create a device with an online of false', (done) ->
      @devices.findOne {}, (error, device) =>
        expect(device.online).to.be.false
        done()

  describe 'when there is an existing device', ->
    beforeEach (done) ->
      @devices.insert {uuid : 'some-uuid', name: 'Somebody.'}, done

    describe 'trying to create a new device with the same uuid', ->
      beforeEach (done) ->
        @updateDevice.yields null, {}
        storeDevice = (@error, @device) => done()
        @sut {uuid: 'some-uuid', name: 'Nobody.'}, storeDevice, @dependencies

      it 'it should call the callback with an error', ->
        expect(@error).to.exist

    describe 'trying to create a new device with a different uuid', ->
      beforeEach (done) ->
        @updateDevice.yields null, {}
        storeDevice = (@error, @device) => done()
        @sut {uuid: 'some-other-uuid'}, storeDevice, @dependencies

      it 'it create a second device', (done) ->
        @database.devices.count {}, (error, count) =>
          return done error if error?
          expect(count).to.equal 2
          done()

  describe 'when called with just a name', ->
    beforeEach (done) ->
      @updateDevice.yields null, {}
      storeDevice = (error, @device) => done()
      @params = {name: 'bobby'}
      @originalParams = _.cloneDeep @params
      @sut @params, storeDevice, @dependencies

    it 'should not mutate the params', ->
      expect(@params).to.deep.equal @originalParams
