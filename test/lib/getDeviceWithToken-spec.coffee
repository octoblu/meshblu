_            = require 'lodash'
TestDatabase = require '../test-database'

describe 'getDeviceWithToken', ->
  beforeEach (done) ->
    @sut = require '../../lib/getDeviceWithToken'
    TestDatabase.open (error, database) =>
      @database = database
      done error

  describe 'when a device does not exist', ->
    beforeEach (done) ->
      storeDevice = (@error, @device) => done()
      @sut 'does-not-exist', storeDevice, @database

    it 'should not have a device', ->
      expect(@device).to.not.exist

    it 'should have an error', ->
      expect(@error).to.exist

  describe 'when a device exists', ->
    beforeEach (done) ->
      @devices = @database.devices
      @devices.insert uuid: 'valid-uuid', token: 'some-token', done

    describe 'when passed a valid uuid', ->
      beforeEach (done) ->
        storeDevice = (@error, @device) => done()
        @sut 'valid-uuid', storeDevice, @database

      it 'should have a device', ->
        expect(@device).to.exist

      it 'should have a token', ->
        expect(@device.token).to.equal 'some-token'

      it 'should not have an error', ->
        expect(@error).to.not.exist
