_ = require 'lodash'
TestDatabase = require '../test-database'

describe 'createSubscriptionIfAuthorized', ->
  beforeEach ->
    @sut = require '../../lib/createSubscriptionIfAuthorized'

  beforeEach (done) ->
    TestDatabase.open (error, database) =>
      @database = database
      @dependencies = database: @database
      done error

  describe 'when called with an invalid type', ->
    beforeEach (done) ->
      storeError = (@error) => done()
      @sut {}, {type: 'invalid'}, storeError

    it 'should yield an error', ->
      expect(@error).to.be.an.instanceOf Error
      expect(@error.message).to.deep.equal 'Type must be one of ["broadcast", "config", "received", "sent"]'

  describe 'when called with an valid type', ->
    beforeEach (done) ->
      storeError = (@error) => done()
      @sut {}, {type: 'broadcast'}, storeError

    it 'should yield not an error', ->
      expect(@error).not.to.be.an.instanceOf Error

  describe 'when we have one open device and one closed device', ->
    beforeEach (done) ->
      @open_device = uuid: 'uuid1', configureWhitelist: ['*']
      @database.devices.insert uuid: 'uuid1', token: 'token1', configureWhitelist: ['*'], done

    beforeEach (done) ->
      @closed_device = uuid: 'uuid2', configureWhitelist: []
      @database.devices.insert uuid: 'uuid2', token: 'token2', configureWhitelist: [], done

    describe 'when the open device creates a subscription from itself to the closed device', ->
      beforeEach (done) ->
        params = {
          subscriberUuid: @open_device.uuid
          emitterUuid: @closed_device.uuid
          type: 'broadcast'
        }

        @dependencies.getDevice = sinon.stub().yields null, @open_device

        @sut @open_device, params, done, @dependencies

      it 'should create exactly one subscription in the database', (done) ->
        @database.subscriptions.count {}, (error, subscriptionCount) =>
          return done error if error?
          expect(subscriptionCount).to.equal 1
          done()

      it 'should create a new subscription for uuid1', (done) ->
        @database.subscriptions.findOne {}, (error, subscription) =>
          return done error if error?
          subscription = _.omit subscription, '_id'
          expect(subscription).to.deep.equal subscriberUuid: @open_device.uuid, emitterUuid: @closed_device.uuid, type: 'broadcast'
          done()

      describe 'if we call it again', ->
        beforeEach (done) ->
          params = {
            subscriberUuid: @open_device.uuid
            emitterUuid: @closed_device.uuid
            type: 'broadcast'
          }

          @dependencies.getDevice = sinon.stub().yields null, @open_device

          @sut @open_device, params, done, @dependencies

        it 'should not create a new subscription in the database', (done) ->
          @database.subscriptions.count {}, (error, subscriptionCount) =>
            return done error if error?
            expect(subscriptionCount).to.equal 1
            done()

    describe 'when someone else creates a subscription from the closed device to the open device', ->
      beforeEach (done) ->
        @other_device = {uuid: 'uuid3'}

        params = {
          subscriberUuid: @closed_device.uuid
          emitterUuid: @open_device.uuid
          type: 'broadcast'
        }

        @dependencies.getDevice = sinon.stub().yields null, @closed_device

        storeError = (@error) => done()
        @sut @other_device, params, storeError, @dependencies

      it 'should create exactly no subscriptions in the database', (done) ->
        @database.subscriptions.count {}, (error, subscriptionCount) =>
          return done error if error?
          expect(subscriptionCount).to.equal 0
          done()

      it 'should yield an error', ->
        expect(@error).to.be.an.instanceOf Error
        expect(@error.message).to.deep.equal 'Insufficient permissions to subscribe on behalf of that device'
