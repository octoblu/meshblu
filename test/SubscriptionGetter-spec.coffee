SubscriptionGetter = require '../lib/SubscriptionGetter'
TestDatabase = require './test-database'

describe 'SubscriptionGetter', ->
  beforeEach (done) ->
    TestDatabase.open (error, database) =>
      {@devices,@subscriptions}  = database
      @devices.find {}, (error, devices) =>
        done error

  describe '->get', ->
    describe 'when given bad information', ->
      beforeEach (done) ->
        @sut = new SubscriptionGetter emitterUuid: 'user-uuid', type: 'boogey-woogey', {@devices, @subscriptions, @simpleAuth}
        @sut.get (@error, @result) => done()

      it 'should have an error', ->
        expect(@error).to.exist

    describe 'when given good information', ->
      beforeEach (done) ->
        @receiverUuid = 'dc8331b5-33b6-47b0-85db-2106930d0601'
        record =
          name: 'Receiver'
          uuid: @receiverUuid
        @devices.insert record, done

      beforeEach (done) ->
        @forwarderUuid = '9749b660-b6dc-4189-b248-1248e72ecb51'
        record =
          name: 'Forwarder'
          uuid: @forwarderUuid
          configureWhitelist: [ @receiverUuid ]
        @devices.insert record, done

      beforeEach (done) ->
        record =
          emitterUuid: @forwarderUuid
          subscriberUuid: @receiverUuid
          type: 'heart'
        @subscriptions.insert record, done

      beforeEach (done) ->
        @sut = new SubscriptionGetter emitterUuid: @forwarderUuid, type: 'heart', {@devices, @subscriptions, @simpleAuth}
        @sut.get (error, @result) => done error

      it 'should return an empty array', ->
        expect(@result).to.contain @receiverUuid
