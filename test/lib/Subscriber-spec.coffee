{createClient} = require '../../lib/redis'
Subscriber = require '../../lib/Subscriber'

describe 'Subscriber', ->
  describe 'when a message is pubbed to the channel', ->
    beforeEach ->
      @redis = createClient()
      @sut = new Subscriber namespace: 'test'

    describe '->close', ->
      it 'should be a function', ->
        @sut.close()

    describe '->subscribe', ->
      describe 'when subscribing', ->
        beforeEach (done) ->
          @sut.once 'message', (@channel, @message) => done()
          @sut.subscribe 'received', 'some-uuid', =>
            @redis.publish 'test:received:some-uuid', JSON.stringify(claws: 'Mee-yow!')

        it 'should receive it', ->
          expect(@message).to.deep.equal claws: 'Mee-yow!'

        it 'should receive it from the correct channel', ->
          expect(@channel).to.deep.equal 'test:received:some-uuid'

      describe 'when subscribing to something else', ->
        beforeEach (done) ->
          @sut.once 'message', (@channel, @message) => done()
          @sut.subscribe 'sent', 'bum-id', =>
            message = JSON.stringify(collapsingShelf: 'There! My brick collection, for all to see!')
            @redis.publish 'test:sent:bum-id', message

        it 'should receive it', ->
          expect(@message).to.deep.equal collapsingShelf: 'There! My brick collection, for all to see!'

        it 'should receive it from the correct channel', ->
          expect(@channel).to.deep.equal 'test:sent:bum-id'

      describe 'when subscribing and redis emits invalid json', ->
        beforeEach (done) ->
          @sut.once 'message', => @error = new Error('received unexpected message')
          @sut.subscribe 'sent', 'bum-id', =>
            @redis.publish 'test:sent:bum-id', 'undefined', done

        it 'should receive it', ->
          expect(@error).not.to.exist

    describe '->unsubscribe', ->
      describe 'when subscribed', ->
        beforeEach (done) ->
          @sut.subscribe 'blah', 'vagrant-id', done

        describe 'when called with that id', ->
          beforeEach (done) ->
            @sut.unsubscribe 'blah', 'vagrant-id', done

            @onMessage = sinon.spy()
            @sut.on 'message', @onMessage

          beforeEach (done) ->
            @redis.publish 'test:blah:vagrant-id', JSON.stringify(defenestration: 'Look it up.'), done

          it 'should never call @onMessage', ->
            expect(@onMessage).not.to.have.been.called.like?.ever?
