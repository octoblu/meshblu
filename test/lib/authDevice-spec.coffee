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
    @database.close()

  it 'should be a function', ->
    expect(@sut).to.be.a 'function'

  describe 'when passed an invalid token and uuid (cause theres nothing in the database)', ->
    beforeEach (done) ->
      storeDevice = (error, @device) => done error
      @sut 'invalid-uuid', 'invalid-token', storeDevice, @database

    it 'should call the callback with no device', ->
      expect(@device).to.not.exist

  describe 'when there is a device', ->
    beforeEach (done) ->
      @devices = @database.collection 'devices'
      @devices.insert uuid: 'valid-uuid', token: bcrypt.hashSync('valid-token', 8), done

    describe 'when passed a valid token and uuid', ->
      beforeEach (done) ->
        storeDevice = (error, @device) => done error
        @sut 'valid-uuid', 'valid-token', storeDevice, @database

      it 'should call the callback with a device', ->
        expect(@device).to.exist

