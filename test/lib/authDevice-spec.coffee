_            = require 'lodash'
bcrypt       = require 'bcrypt'
TestDatabase = require '../test-database'

describe 'authDevice', ->
  beforeEach (done) ->
    @sut = require '../../lib/authDevice'
    TestDatabase.open (error, database) =>
      @database = database
      done error

  afterEach ->
    @database.close?()

  it 'should be a function', ->
    expect(@sut).to.be.a 'function'

  describe 'when passed an invalid token and uuid (cause theres nothing in the database)', ->
    beforeEach (done) ->
      storeResults = (@error, @device) => done()
      @sut 'invalid-uuid', 'invalid-token', storeResults, @database

    it 'should call the callback with no device', ->
      expect(@device).to.not.exist

    it 'should call the callback with an error', ->
      expect(@error).to.exist

  describe 'when there is a device', ->
    beforeEach (done) ->
      @devices = @database.devices
      @devices.insert uuid: 'valid-uuid', token: bcrypt.hashSync('valid-token', 8), done

    describe 'when passed a valid token and uuid', ->
      beforeEach (done) ->
        storeResults = (error, @device) => done error
        @sut 'valid-uuid', 'valid-token', storeResults, @database

      it 'should call the callback with a device', ->
        expect(@device).to.exist

      it 'should not pass the token back', ->
        expect(@device.token).to.not.exist

    describe 'when passed a valid uuid and invalid token', ->
      beforeEach (done) ->
        storeResults = (@error, @device) => done()
        @sut 'valid-uuid', 'invalid-token', storeResults, @database

      it 'should call the callback with no device', ->
        expect(@device).not.to.exist

      it 'should call the callback with no error', ->
        expect(@error).not.to.exist

  describe 'when the device in the database has tokens', ->
    beforeEach (done) ->
      @devices = @database.devices
      @devices.insert uuid: 'scrooge', tokens: [{hash: bcrypt.hashSync('money', 8)}], done

    describe 'when passed a valid uuid and token', ->
      beforeEach (done) ->
        storeResults = (@error, @device) => done()
        @sut 'scrooge', 'money', storeResults, @database

      it 'should call the callback with a device', ->
        expect(@device).to.exist

      it 'should call the callback with no error', ->
        expect(@error).not.to.exist

    describe 'when passed a valid uuid and an invalid token', ->
      beforeEach (done) ->
        storeResults = (@error, @device) => done()
        @sut 'scrooge', 'pants', storeResults, @database

      it 'should call the callback with no device', ->
        expect(@device).not.to.exist

      it 'should call the callback with no error', ->
        expect(@error).not.to.exist






