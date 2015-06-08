MessageIOEmitter = require '../../lib/messageIOEmitter'

describe 'MessageIOEmitter', ->
  beforeEach ->
    @sut = new MessageIOEmitter

  describe 'addEmitter', ->
    beforeEach ->
      @sut.addEmitter heck: 'yes'

    it 'should add to emitters', ->
      expect(@sut.emitters).to.contain heck: 'yes'

  describe 'emit', ->
    describe 'when one', ->
      beforeEach ->
        @emitter = {}
        @emitter.in = sinon.stub().returns @emitter
        @emitter.emit = sinon.spy()

        @sut.addEmitter @emitter
        @sut.emit 'foo', 'topic', 'data'

      it 'should call in', ->
        expect(@emitter.in).to.have.been.calledWith 'foo'

      it 'should call emit', ->
        expect(@emitter.emit).to.have.been.calledWith 'topic', 'data'

    describe 'when two', ->
      beforeEach ->
        @emitter_1 = {}
        @emitter_1.in = sinon.stub().returns @emitter_1
        @emitter_1.emit = sinon.spy()
        @emitter_2 = {}
        @emitter_2.in = sinon.stub().returns @emitter_2
        @emitter_2.emit = sinon.spy()

        @sut.addEmitter @emitter_1
        @sut.addEmitter @emitter_2
        @sut.emit 'foo', 'topic', 'data'

      it 'should call in on emitter_1', ->
        expect(@emitter_1.in).to.have.been.calledWith 'foo'

      it 'should call emit on emitter_1', ->
        expect(@emitter_1.emit).to.have.been.calledWith 'topic', 'data'

      it 'should call in on emitter_2', ->
        expect(@emitter_2.in).to.have.been.calledWith 'foo'

      it 'should call emit on emitter_2', ->
        expect(@emitter_2.emit).to.have.been.calledWith 'topic', 'data'
