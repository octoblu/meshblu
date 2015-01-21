uuid         = require 'node-uuid'
bcrypt       = require 'bcrypt'
TestDatabase = require '../test-database'

describe 'Update Device', ->
  beforeEach (done) ->
    @sut = require '../../lib/updateDevice'
    TestDatabase.open (error, database) =>
      @database = database
      @devices  = @database.collection 'devices'
      done error

  afterEach ->
    @database.close()

  it 'should be a function', ->
    expect(@sut).to.be.a 'function'

  describe 'when called with nothing', ->
    beforeEach (done) ->
      storeError = (@error, device) => done()
      @sut null, null, storeError, @database

    it 'should call its callback with an error', ->
      expect(@error).to.exist

  describe 'when called with a uuid that doesnt exist', ->
    beforeEach (done) ->
      storeError = (@error, device) => done()
      @sut 'not-real', null, storeError, @database

    it 'should call its callback with an error', ->
      expect(@error).to.exist

  describe 'when a device exists', ->
    beforeEach (done) ->
      @uuid = uuid.v1()
      @rawToken = 'akuma'
      @token = bcrypt.hashSync(@rawToken, 8)
      @orginalDevice = {uuid: @uuid, name: 'hadoken', token : @token, online :true}
      @devices.insert @orginalDevice, done

    describe 'when update is called with that uuid and different name', ->
      beforeEach (done) ->
        @sut @uuid, {name: 'shakunetsu'}, done, @database

      it 'should update the record', (done) ->
        @devices.findOne {uuid: @uuid}, (error, device) ->
          done error if error?
          expect(device.name).to.equal 'shakunetsu'
          done()

    describe 'when update is called with that uuid and the same name', ->
      beforeEach (done) ->
        @sut @uuid, {name: 'hadoken'}, done, @database

      it 'should update the record', (done) ->
        @devices.findOne {uuid: @uuid}, (error, device) ->
          done error if error?
          expect(device.name).to.equal 'hadoken'
          done()

    describe 'when update is called with one good and one bad param', ->
      beforeEach (done) ->
        @sut @uuid, {name: 'guile', '$natto': 'fermented soybeans'}, done, @database

      it 'should update the record', (done) ->
        @devices.findOne {uuid: @uuid}, (error, device) ->
          done error if error?
          expect(device.name).to.equal 'guile'
          expect(device['$natto']).to.not.exist
          done()

    describe 'when update is called with a nested bad param', ->
      beforeEach (done) ->
        @sut @uuid, {name: 'guile', foo: {'$natto': 'fermented soybeans'}}, done, @database

      it 'should update the record', (done) ->
        @devices.findOne {uuid: @uuid}, (error, device) ->
          done error if error?
          expect(device.name).to.equal 'guile'
          expect(device.foo).to.deep.equal {}
          done()

    describe 'when update is called with that uuid and the same name', ->
      beforeEach (done) ->
        storeDevice = (@error, @device) => done()
        @sut @uuid, {name: 'hadoken'}, storeDevice, @database

      it 'should update the record', ->
        expect(@device.name).to.equal 'hadoken'

    describe 'when updated with a token', ->
      beforeEach (done) ->
        @device = { name: 'ken masters', token : 'masters ken' }
        @sut @uuid, @device, done, @database

      it 'should update a hash of the token', (done) ->
        @database.devices.findOne { uuid: @uuid }, (error, storeDevice) =>
          return done error if error?
          expect(bcrypt.compareSync(@device.token, storeDevice.token)).to.be.true
          done()

    describe 'when updated without a token', ->
      beforeEach (done) ->
        @device = { name: 'shin akuma' }
        @sut @uuid, @device, done, @database

      it 'should not update the token', (done) ->
        @database.devices.findOne { uuid: @uuid }, (error, storeDevice) =>
          return done error if error?
          expect(bcrypt.compareSync(@rawToken, storeDevice.token)).to.be.true
          done()

    describe 'when updated with an online of "false"', ->
      beforeEach (done) ->
        @sut @uuid, {online: 'false'}, done, @database

      it 'should create a device with an online of true', (done) ->
        @devices.findOne (error, device) =>
          expect(device.online).to.be.true
          done()

    describe 'when updated with an online of false', ->
      beforeEach (done) ->
        @sut @uuid, {online: false}, done, @database

      it 'should create a device with an online of true', (done) ->
        @devices.findOne (error, device) =>
          expect(device.online).to.be.false
          done()
