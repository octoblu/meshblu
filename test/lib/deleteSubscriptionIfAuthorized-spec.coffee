_ = require 'lodash'
TestDatabase = require '../test-database'

describe 'deleteSubscriptionIfAuthorized', ->
  beforeEach ->
    @sut = require '../../lib/deleteSubscriptionIfAuthorized'

  beforeEach (done) ->
    TestDatabase.open (error, database) =>
      @database = database
      @dependencies = database: @database
      done error

  describe 'when there is a closed device and an open device', ->
    beforeEach (done) ->
      @open_device = uuid: 'uuid1', configureWhitelist: ['*']
      @database.devices.insert uuid: 'uuid1', token: 'token1', configureWhitelist: ['*'], done

    beforeEach (done) ->
      @closed_device = uuid: 'uuid2', configureWhitelist: []
      @database.devices.insert uuid: 'uuid2', token: 'token2', configureWhitelist: [], done

    describe 'when the devices are subscribed to each other', ->
      beforeEach (done) ->
        @database.subscriptions.insert subscriberUuid: @open_device.uuid, emitterUuid: @closed_device.uuid, type: 'event', done

      beforeEach (done) ->
        @database.subscriptions.insert subscriberUuid: @closed_device.uuid, emitterUuid: @open_device.uuid, type: 'event', done

      describe 'when the open device tries to remove a subscription from itself to the closed device', ->
        beforeEach (done) ->
          params = {
            uuid: @open_device.uuid
            targetUuid: @closed_device.uuid
            type: 'event'
          }

          @dependencies.getDevice = sinon.stub().yields null, @open_device

          @sut @open_device, params, done, @dependencies

        it 'should remove exactly one subscription from the database', (done) ->
          @database.subscriptions.count {}, (error, subscriptionCount) =>
            return done error if error?
            expect(subscriptionCount).to.equal 1
            done()

      describe 'when someone else tries to remove the subscription from the closed device to the open device', ->
        beforeEach (done) ->
          @other_device = {uuid: 'uuid3'}

          params = {
            uuid: @closed_device.uuid
            targetUuid: @open_device.uuid
            type: 'event'
          }

          @dependencies.getDevice = sinon.stub().yields null, @closed_device

          storeError = (@error) => done()
          @sut @other_device, params, storeError, @dependencies

        it 'should remove no subscriptions from the database', (done) ->
          @database.subscriptions.count {}, (error, subscriptionCount) =>
            return done error if error?
            expect(subscriptionCount).to.equal 2
            done()

        it 'should yield an error', ->
          expect(@error).to.be.an.instanceOf Error
          expect(@error.message).to.deep.equal 'Insufficient permissions to remove subscription on behalf of that device'
