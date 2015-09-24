SubscriptionGetter = require '../lib/SubscriptionGetter'

describe 'SubscriptionGetter', ->
  beforeEach ->
    @dependencies =
      subscriptions:
        find: sinon.stub()
      simpleAuth:
        canReceive: sinon.stub() # (fromDevice, toDevice, message, callback)
      getDevice: sinon.stub()

    @sut = new SubscriptionGetter {}, @dependencies

  describe '->get', ->
    describe 'when given bad information', ->
      beforeEach (done) ->
        @sut = new SubscriptionGetter emitterUuid: 'user-uuid', type: 'boogey-woogey', @dependencies
        @dependencies.subscriptions.find.yields null, [{subscriberUuid: 'one-bad-uuid'}]
        @dependencies.getDevice.withArgs('user-uuid').yields null, {first: 'object'}
        @dependencies.getDevice.withArgs('one-bad-uuid').yields null, {second: 'object'}
        @dependencies.simpleAuth.canReceive.yields null, false
        @sut.get (@error, @result) => done()

      it 'should call find', ->
        expect(@dependencies.subscriptions.find).to.have.been.calledWith
          emitterUuid: 'user-uuid'
          type: 'boogey-woogey'

      it 'should call canReceive with the two devices', ->
        expect(@dependencies.simpleAuth.canReceive).to.have.been.calledWith(
          {second: 'object'}
          {first: 'object'}
        )

      it 'should return an empty array', ->
        expect(@result).to.deep.equal []

    describe 'when getDevice yields an error', ->
      beforeEach (done) ->
        @sut = new SubscriptionGetter emitterUuid: 'the-uuid', type: 'broadcast', @dependencies
        @dependencies.getDevice.yields new Error('oops')
        @sut.get (@error, @result) => done()

      it 'should yield an error', ->
        expect(=> throw @error).to.throw 'oops'

    describe 'when subscriptions yields an error', ->
      beforeEach (done) ->
        @sut = new SubscriptionGetter emitterUuid: 'the-uuid', type: 'broadcast', @dependencies
        @dependencies.getDevice.yields null, {}
        @dependencies.subscriptions.find.yields new Error('yikes!')
        @sut.get (@error, @result) => done()

      it 'should yield an error', ->
        expect(=> throw @error).to.throw 'yikes!'

    describe 'when the second getDevice yields an error', ->
      beforeEach (done) ->
        @sut = new SubscriptionGetter emitterUuid: 'the-uuid', type: 'broadcast', @dependencies
        @dependencies.getDevice.onCall(0).yields null, {}
        @dependencies.subscriptions.find.yields null, [{}]
        @dependencies.getDevice.onCall(1).yields new Error 'ops'
        @sut.get (@error, @result) => done()

      it 'should yield an error', ->
        expect(=> throw @error).to.throw 'ops'

    describe 'when the canReceive yields an error', ->
      beforeEach (done) ->
        @sut = new SubscriptionGetter emitterUuid: 'the-uuid', type: 'broadcast', @dependencies
        @dependencies.getDevice.onCall(0).yields null, {}
        @dependencies.subscriptions.find.yields null, [{}]
        @dependencies.getDevice.onCall(1).yields null, {}
        @dependencies.simpleAuth.canReceive.yields new Error 'heyya!'
        @sut.get (@error, @result) => done()

      it 'should yield an error', ->
        expect(=> throw @error).to.throw 'heyya!'
