async = require 'async'
config = require '../../config'
{createClient} = require '../../lib/redis'
MessageIOClient = require '../../lib/messageIOClient'

describe 'MessageIOClient', ->
  beforeEach ->
    @redis = createClient()
    @sut = new MessageIOClient namespace: 'test'

  describe 'emitting config events', ->
    beforeEach ->
      @onConfig = sinon.spy()
      @onMessage = sinon.spy()
      @sut.once 'config', @onConfig
      @sut.once 'message', @onMessage

    describe 'when subscribed to config and sent events', ->
      beforeEach (done) ->
        @sut.subscribe 'uuid', ['config','sent'], undefined, done

      describe 'when redis pubs a config event', ->
        beforeEach (done) ->
          @sut.once 'config', => done()
          @redis.publish 'test:config:uuid', JSON.stringify(uneven: 'carpet')

        it 'should emit the config event', ->
          expect(@onConfig).to.have.been.calledWith uneven: 'carpet'

        it 'should not emit the message event', ->
          expect(@onMessage).not.to.have.been.called

      describe 'when redis pubs a sent event', ->
        beforeEach ->
          @redis.publish 'test:sent:uuid', JSON.stringify(uneven: 'carpet')

        beforeEach (done) ->
          setTimeout done, 100

        it 'should not emit the config event', ->
          expect(@onConfig).not.to.have.been.called

  describe 'emitting data events', ->
    beforeEach ->
      @onConfig = sinon.spy()
      @onMessage = sinon.spy()
      @sut.once 'data', @onConfig
      @sut.once 'message', @onMessage

    describe 'when subscribed to data and sent events', ->
      beforeEach (done) ->
        @sut.subscribe 'uuid', ['data','sent'], undefined, done

      describe 'when redis pubs a data event', ->
        beforeEach (done) ->
          @sut.once 'data', => done()
          @redis.publish 'test:data:uuid', JSON.stringify(uneven: 'carpet')

        it 'should emit the data event', ->
          expect(@onConfig).to.have.been.calledWith uneven: 'carpet'

        it 'should not emit the message event', ->
          expect(@onMessage).not.to.have.been.called

      describe 'when redis pubs a sent event', ->
        beforeEach ->
          @redis.publish 'test:sent:uuid', JSON.stringify(uneven: 'carpet')

        beforeEach (done) ->
          setTimeout done, 100

        it 'should not emit the data event', ->
          expect(@onConfig).not.to.have.been.called

  describe 'topic filtering onMessage', ->
    beforeEach ->
      @onMessage = sinon.spy()
      @sut.once 'message', @onMessage

    describe 'when the topic is a string', ->
      beforeEach (done) ->
        @sut.subscribe 'apple', ['received'], ['pears'], done

      describe 'when given the same string', ->
        beforeEach (done) ->
          @sut.once 'message', => done()
          message = devices: ['apple'], topic: 'pears', payload: 'hi'
          @redis.publish 'test:received:apple', JSON.stringify(message)

        it 'emit the message', ->
          expect(@onMessage).to.have.been.calledWith devices: ['apple'], topic: 'pears', payload: 'hi'

      describe 'when given the wrong string', ->
        beforeEach ->
          message = devices: ['apple'], topic: 'bears', payload: 'hi'
          @redis.publish 'test:received:apple', JSON.stringify(message)

        beforeEach (done) ->
          setTimeout done, 100

        it 'should not emit the message', ->
          expect(@onMessage).not.to.have.been.called

    describe 'when the topic ends in a wildcard', ->
      beforeEach (done) ->
        @sut.subscribe 'apple', ['received'], ['pear*'], done

      describe 'when given the same string', ->
        beforeEach (done) ->
          @sut.once 'message', => done()
          message = devices: ['apple'], topic: 'pear', payload: 'hi'
          @redis.publish 'test:received:apple', JSON.stringify(message)

        it 'should emit the message', ->
          expect(@onMessage).to.have.been.called

      describe 'when given one more character', ->
        beforeEach (done) ->
          @sut.once 'message', => done()
          message = devices: ['apple'], topic: 'pears', payload: 'hi'
          @redis.publish 'test:received:apple', JSON.stringify(message)

        it 'should emit the message', ->
          expect(@onMessage).to.have.been.called

      describe 'when given a longer string', ->
        beforeEach (done) ->
          @sut.once 'message', => done()
          message = devices: ['apple'], topic: 'pearson', payload: 'hi'
          @redis.publish 'test:received:apple', JSON.stringify(message)

        it 'should emit the message', ->
          expect(@onMessage).to.have.been.called

      describe 'when given a different string', ->
        beforeEach ->
          message = devices: ['apple'], topic: 'paer', payload: 'hi'
          @redis.publish 'test:received:apple', JSON.stringify(message)

        beforeEach (done) ->
          setTimeout done, 100

        it 'should not emit the message', ->
          expect(@onMessage).not.to.have.been.called

    describe 'when the topic starts and ends in a wildcard', ->
      beforeEach (done) ->
        @sut.subscribe 'apple', ['received'], ['*ear*'], done

      describe 'when given the same string', ->
        beforeEach (done) ->
          @sut.once 'message', => done()
          message = devices: ['apple'], topic: 'pear', payload: 'hi'
          @redis.publish 'test:received:apple', JSON.stringify(message)

        it 'should emit the message', ->
          expect(@onMessage).to.have.been.called

      describe 'when given one more character', ->
        beforeEach (done) ->
          @sut.once 'message', => done()
          message = devices: ['apple'], topic: 'pears', payload: 'hi'
          @redis.publish 'test:received:apple', JSON.stringify(message)

        it 'should emit the message', ->
          expect(@onMessage).to.have.been.called

      describe 'when given a longer string', ->
        beforeEach (done) ->
          @sut.once 'message', => done()
          message = devices: ['apple'], topic: 'pearson', payload: 'hi'
          @redis.publish 'test:received:apple', JSON.stringify(message)

        it 'should emit the message', ->
          expect(@onMessage).to.have.been.called

      describe 'when given a different string', ->
        beforeEach ->
          message = devices: ['apple'], topic: 'paer', payload: 'hi'
          @redis.publish 'test:received:apple', JSON.stringify(message)

        beforeEach (done) ->
          setTimeout done, 100

        it 'should not emit the message', ->
          expect(@onMessage).not.to.have.been.called

    describe 'when the topic contains a wildcard', ->
      beforeEach (done) ->
        @sut.subscribe 'apple', ['received'], ['p*r'], done

      describe 'when given a matching string', ->
        beforeEach (done) ->
          @sut.once 'message', => done()
          message = devices: ['apple'], topic: 'pear', payload: 'hi'
          @redis.publish 'test:received:apple', JSON.stringify(message)

        it 'should emit the message', ->
          expect(@onMessage).to.have.been.called

      describe 'given another matching string', ->
        beforeEach (done) ->
          @sut.once 'message', => done()
          message = devices: ['apple'], topic: 'paer', payload: 'hi'
          @redis.publish 'test:received:apple', JSON.stringify(message)

        it 'should emit the message', ->
          expect(@onMessage).to.have.been.called

      describe 'when given a non-matching string', ->
        beforeEach ->
          message = devices: ['apple'], topic: 'raer', payload: 'hi'
          @redis.publish 'test:received:apple', JSON.stringify(message)

        beforeEach (done) ->
          setTimeout done, 100

        it 'should not emit the message', ->
          expect(@onMessage).not.to.have.been.called

    describe 'when the topic contains a minus', ->
      beforeEach (done) ->
        @sut.subscribe 'apple', ['received'], ['-pears'], done

      describe 'when given a matching string', ->
        beforeEach ->
          message = devices: ['apple'], topic: 'pears', payload: 'hi'
          @redis.publish 'test:received:apple', JSON.stringify(message)

        beforeEach (done) ->
          setTimeout done, 100

        it 'should not emit the message', ->
          expect(@onMessage).not.to.have.been.called

      describe 'when given a non-matching string', ->
        beforeEach (done) ->
          @sut.once 'message', => done()
          message = devices: ['apple'], topic: 'paer', payload: 'hi'
          @redis.publish 'test:received:apple', JSON.stringify(message)

        it 'should emit the message', ->
          expect(@onMessage).to.have.been.called

    describe 'when the topic contains a minus and a wildcard', ->
      beforeEach (done) ->
        @sut.subscribe 'apple', ['received'], ['-p*r*'], done

      describe 'when given a matching string', ->
        beforeEach ->
          message = devices: ['apple'], topic: 'pears', payload: 'hi'
          @redis.publish 'test:received:apple', JSON.stringify(message)

        beforeEach (done) ->
          setTimeout done, 100

        it 'should not emit the message', ->
          expect(@onMessage).not.to.have.been.called

      describe 'when given a non-matching string', ->
        beforeEach ->
          message = devices: ['apple'], topic: 'paer', payload: 'hi'
          @redis.publish 'test:received:apple', JSON.stringify(message)

        beforeEach (done) ->
          setTimeout done, 100

        it 'should not emit the message', ->
          expect(@onMessage).not.to.have.been.called

      describe 'when given a non-matching string', ->
        beforeEach (done) ->
          @sut.once 'message', => done()
          message = devices: ['apple'], topic: 'dear', payload: 'hi'
          @redis.publish 'test:received:apple', JSON.stringify(message)

        it 'should emit the message', ->
          expect(@onMessage).to.have.been.called

  describe 'subscribe', ->
    describe 'received only', ->
      beforeEach (done) ->
        @sut.subscribe 'apple', ['received'], undefined, done

      beforeEach (done) ->
        @sut.once 'message', (@message) => done()
        @redis.publish 'test:received:apple', JSON.stringify(dehydration: 'WATER you DOING?')

      it 'should get a message', ->
        expect(@message).to.deep.equal dehydration: 'WATER you DOING?'

    describe 'sent only', ->
      beforeEach (done) ->
        @sut.subscribe 'hubris', ['sent'], undefined, done

      beforeEach (done) ->
        @sut.once 'message', (@message) => done()
        @redis.publish 'test:sent:hubris', JSON.stringify(that: 'would never happen to me!')

      it 'should get a message', ->
        expect(@message).to.deep.equal that: 'would never happen to me!'

    describe 'broadcast only', ->
      beforeEach (done) ->
        @sut.subscribe 'hubris', ['broadcast'], undefined, done

      beforeEach (done) ->
        @sut.once 'message', (@message) => done()
        @redis.publish 'test:broadcast:hubris', JSON.stringify(that: 'would never happen to me!')

      it 'should get a message', ->
        expect(@message).to.deep.equal that: 'would never happen to me!'

    describe 'all kinds', ->
      beforeEach (done) ->
        @sut.subscribe 'heart', ['broadcast', 'sent', 'received'], undefined, done

      describe 'receiving a broadcast message', ->
        beforeEach (done) ->
          @sut.once 'message', (@message) => done()
          @redis.publish 'test:broadcast:heart', JSON.stringify(couldBe: 'The 80s band')

        it 'should get a broadcast message', ->
          expect(@message).to.deep.equal couldBe: 'The 80s band'

      describe 'receiving a received message', ->
        beforeEach (done) ->
          @sut.once 'message', (@message) => done()
          @redis.publish 'test:received:heart', JSON.stringify(couldBe: 'lovesick?')

        it 'should get a received message', ->
          expect(@message).to.deep.equal couldBe: 'lovesick?'

      describe 'receiving a received message', ->
        beforeEach (done) ->
          @sut.once 'message', (@message) => done()
          @redis.publish 'test:received:heart', JSON.stringify(couldBe: 'lovesick?')

        it 'should get a received message', ->
          expect(@message).to.deep.equal couldBe: 'lovesick?'

  describe 'unsubscribe', ->
    describe 'received only', ->
      beforeEach (done) ->
        @onMessage = sinon.spy()
        @sut.once 'message', @onMessage
        @sut.subscribe 'apple', ['received'], undefined, =>
          @sut.unsubscribe 'apple', ['received'], =>
            @redis.publish 'test:received:apple', JSON.stringify(dehydration: 'WATER you DOING?'), done

      beforeEach (done) ->
        setTimeout done, 100

      it 'should not get a message', ->
        expect(@onMessage).not.to.have.been.called

    describe 'sent only', ->
      beforeEach (done) ->
        @onMessage = sinon.spy()
        @sut.once 'message', @onMessage
        @sut.subscribe 'hubris', ['sent'], undefined, =>
          @sut.unsubscribe 'hubris', ['sent'], =>
            @redis.publish 'test:sent:hubris', JSON.stringify(that: 'would never happen to me!'), done

      it 'should not get a message', ->
        expect(@onMessage).not.to.have.been.called

    describe 'broadcast only', ->
      beforeEach (done) ->
        @onMessage = sinon.spy()
        @sut.once 'message', @onMessage
        @sut.subscribe 'hubris', ['broadcast'], undefined, =>
          @sut.unsubscribe 'hubris', ['broadcast'], =>
            @redis.publish 'test:broadcast:hubris', JSON.stringify(that: 'would never happen to me!'), done

      beforeEach (done) ->
        setTimeout done, 100

      it 'should not get a message', ->
        expect(@onMessage).not.to.have.been.called

    describe 'all kinds', ->
      beforeEach (done) ->
        @onMessage = sinon.spy()
        @sut.once 'message', @onMessage
        @sut.subscribe 'heart', ['broadcast', 'sent', 'received'], undefined, =>
          @sut.unsubscribe 'heart', ['broadcast', 'sent', 'received'], done

      describe 'receiving a broadcast message', ->
        beforeEach (done) ->
          @redis.publish 'test:broadcast:heart', JSON.stringify(couldBe: 'The 80s band'), done

        it 'should not get any', ->
          expect(@onMessage).not.to.have.been.called

      describe 'receiving a received message', ->
        beforeEach (done) ->
          @redis.publish 'test:received:heart', JSON.stringify(couldBe: 'lovesick?'), done

        it 'should not get any', ->
          expect(@onMessage).not.to.have.been.called

      describe 'receiving a received message', ->
        beforeEach (done) ->
          @redis.publish 'test:received:heart', JSON.stringify(couldBe: 'lovesick?'), done

        it 'should not get any', ->
          expect(@onMessage).not.to.have.been.called

    describe 'no kinds', ->
      beforeEach (done) ->
        @onMessage = sinon.spy()
        @sut.once 'message', @onMessage
        @sut.subscribe 'heart', undefined, undefined, =>
          @sut.unsubscribe 'heart', undefined, done

      describe 'receiving a broadcast message', ->
        beforeEach ->
          @redis.publish 'test:broadcast:heart', JSON.stringify(couldBe: 'The 80s band')

        beforeEach (done) ->
          setTimeout done, 100

        it 'should not get any', ->
          expect(@onMessage).not.to.have.been.called

      describe 'receiving a received message', ->
        beforeEach ->
          @redis.publish 'test:received:heart', JSON.stringify(couldBe: 'lovesick?')

        beforeEach (done) ->
          setTimeout done, 100

        it 'should not get any', ->
          expect(@onMessage).not.to.have.been.called

      describe 'receiving a received message', ->
        beforeEach ->
          @redis.publish 'test:received:heart', JSON.stringify(couldBe: 'lovesick?')

        beforeEach (done) ->
          setTimeout done, 100

        it 'should not get any', ->
          expect(@onMessage).not.to.have.been.called

  describe 'close', ->
    it 'should be a function', ->
      @sut.close()
