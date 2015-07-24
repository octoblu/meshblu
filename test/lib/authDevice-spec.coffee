_            = require 'lodash'
bcrypt       = require 'bcrypt'
TestDatabase = require '../test-database'

describe 'authDevice', ->
  beforeEach ->
    @sut = require '../../lib/authDevice'
    @device = verifyToken: sinon.stub(), fetch: sinon.stub()
    console.log("DEVICE", @device);
    @dependencies =
      getDeviceWithToken : sinon.stub()
      Device : sinon.spy => @device

  describe 'when passed an invalid token and uuid (cause theres nothing in the database)', ->
    beforeEach (done) ->
      console.log("DEVICE", @device);
      @device.verifyToken.yields new Error('Unable to find valid device')
      storeResults = (@error, @returnDevice) => done()
      @sut 'invalid-uuid', 'invalid-token', storeResults, @dependencies

    it 'should call the callback with no device', ->
      expect(@returnDevice).to.not.exist

    it 'should call the callback with an error', ->
      expect(@error).to.exist

  describe 'when passed a valid token and uuid', ->
    beforeEach (done) ->
      @device.verifyToken.yields null, false
      @device.fetch.yields null, {}
      storeResults = (@error, @returnDevice) => done()
      @sut 'valid-uuid', 'invalid-token', storeResults, @dependencies

    it 'should call the callback with a device', ->
      expect(@returnDevice).to.not.exist

    it 'should call fetch', ->
      expect(@device.fetch).to.not.have.been.called

    it 'should call the callback without an error', ->
      expect(@error).to.exist

  describe 'when passed a valid token and uuid', ->
    beforeEach (done) ->
      @device.verifyToken.yields null, true
      @device.fetch.yields null, {}
      storeResults = (@error, @returnDevice) => done()
      @sut 'invalid-uuid', 'invalid-token', storeResults, @dependencies

    it 'should call the callback with a device', ->
      expect(@returnDevice).to.exist

    it 'should call fetch', ->
      expect(@device.fetch).to.have.been.called

    it 'should call the callback without an error', ->
      expect(@error).to.not.exist
