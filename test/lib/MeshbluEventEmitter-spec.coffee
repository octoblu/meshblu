MeshbluEventEmitter = require '../../lib/MeshbluEventEmitter'

describe 'MeshbluEventEmitter', ->
  beforeEach ->
    @sendMessage = sinon.spy()

  describe '->emit', ->
    describe 'when it has two uuids', ->
      beforeEach ->
        uuids = ['some-uuid','some-other-uuid']
        @sut = new MeshbluEventEmitter 'meshblu-uuid', uuids, @sendMessage

      describe 'when called with an eventType and payload', ->
        beforeEach ->
          @sut.emit 'update', {'$set': {foo: 'bar'}}

        it 'should call sendMessage with a message', ->
          expect(@sendMessage).to.have.been.calledWith(uuid: 'meshblu-uuid', {
            devices: ['some-uuid','some-other-uuid']
            topic: 'update'
            payload: {'$set': {foo: 'bar'}}
          })
