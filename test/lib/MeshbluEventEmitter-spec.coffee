_ = require 'lodash'
MeshbluEventEmitter = require '../../lib/MeshbluEventEmitter'

describe 'MeshbluEventEmitter', ->
  beforeEach ->
    @sendMessage = sinon.spy()

  describe '->emit', ->
    describe 'when it has two uuids', ->
      beforeEach ->
        uuids = ['some-uuid','some-other-uuid']
        @Date = sinon.stub().returns toJSON: -> '2015-08-11T22:15:06.302Z'
        @sut = new MeshbluEventEmitter 'meshblu-uuid', uuids, @sendMessage, Date: @Date

      describe 'when called with an eventType and payload', ->
        beforeEach ->
          @sut.emit 'update', {'$set': {foo: 'bar'}}

        it 'should call sendMessage with a message', ->
          expect(@sendMessage).to.have.been.calledWith(uuid: 'meshblu-uuid', {
            devices: ['some-uuid','some-other-uuid']
            topic: 'update'
            payload: {'$set': {foo: 'bar'}, _timestamp: '2015-08-11T22:15:06.302Z'}
          })
