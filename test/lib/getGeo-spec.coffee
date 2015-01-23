_            = require 'lodash'
uuid         = require 'node-uuid'

describe 'Get Geo', ->
  beforeEach ->
    @lookup = sinon.stub()
    @geoip = {lookup: @lookup}
    @dependencies = {geoip: @geoip}
    @sut = require '../../lib/getGeo'

  it 'should be a function', ->
    expect(@sut).to.be.a 'function'

  describe 'when called with nothing', ->
    beforeEach (done) ->
      storeGeo = (@error) => done()
      @sut null, storeGeo

    it 'should call its callback with an error', ->
      expect(@error).to.exist

  describe 'when called with a valid ipAddress', ->
    beforeEach (done) ->
      @lookup.returns {}
      storeGeo = (@error, @geo) => done()
      @sut '192.168.0.1', storeGeo, @dependencies

    it 'should return a geo', ->
      expect(@geo).to.exist

  describe 'when called with a valid ipAddress that has no matching geo', ->
    beforeEach (done) ->
      @lookup.returns null 
      storeGeo = (@error, @geo) => done()
      @sut '1.0.0.1', storeGeo, @dependencies

    it 'should return an error', ->
      expect(@error).to.exist

    it 'should not return an error', ->
      expect(@geo).not.to.exist
