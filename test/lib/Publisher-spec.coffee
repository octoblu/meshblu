async = require 'async'
Publisher = require '../../lib/Publisher'
{createClient} = require '../../lib/redis'

describe 'Publisher', ->
  beforeEach ->
    @redis = createClient()

  describe '->publish', ->
    describe 'when called with undefined', ->
      beforeEach (done) ->
        @sut = new Publisher namespace: 'test'
        @redis.subscribe 'test:received:mah-uuid', done

      beforeEach (done) ->
        @onMessage = sinon.spy()
        @redis.once 'message', @onMessage
        @sut.publish 'received', 'mah-uuid', undefined, (@error) => done()

      it 'should not publish into redis', ->
        expect(@onMessage).not.to.have.been.called

      it 'should have an error', ->
        expect(@error.message).to.equal 'Invalid message'

    describe 'when called', ->
      beforeEach (done) ->
        @sut = new Publisher namespace: 'test'
        @redis.subscribe 'test:received:mah-uuid', done

      beforeEach (done) ->
        @redis.once 'message', (@channel,@message) => done()
        @sut.publish 'received', 'mah-uuid', bee_sting: 'hey, free honey!'

      it 'should publish into redis', ->
        expect(JSON.parse @message).to.deep.equal bee_sting: 'hey, free honey!'

      it 'should publish into the correct channel', ->
        expect(@channel).to.deep.equal 'test:received:mah-uuid'
