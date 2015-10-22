Publisher = require '../../lib/Publisher'
{createClient} = require '../../lib/redis'

describe 'Publisher', ->
  beforeEach ->
    @redis = createClient()

  describe '->publish', ->
    describe 'when called', ->
      beforeEach (done) ->
        @sut = new Publisher uuid: 'mah-uuid', namespace: 'test'
        @redis.subscribe 'test:mah-uuid', done

      beforeEach (done) ->
        @redis.once 'message', (@channel,@message) => done()
        @sut.publish bee_sting: 'hey, free honey!'

      it 'should publish into redis', ->
        expect(JSON.parse @message).to.deep.equal bee_sting: 'hey, free honey!'

      it 'should publish into the correct channel', ->
        expect(@channel).to.deep.equal 'test:mah-uuid'

    describe 'when called again', ->
      beforeEach (done) ->
        @sut = new Publisher uuid: 'yer-id', namespace: 'testy'
        @redis.subscribe 'testy:yer-id', done

      beforeEach (done) ->
        @redis.once 'message', (@channel,@message) =>
        @sut.publish carnivorousPlant: 'Feed me, Seymour!', done

      it 'should publish into redis', ->
        expect(JSON.parse @message).to.deep.equal carnivorousPlant: 'Feed me, Seymour!'

      it 'should publish into the correct channel', ->
        expect(@channel).to.deep.equal 'testy:yer-id'
