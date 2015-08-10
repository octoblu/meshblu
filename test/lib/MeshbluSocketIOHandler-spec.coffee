{EventEmitter} = require 'events'
MeshbluSocketIOHandler = require '../../lib/MeshbluSocketIOHandler'

describe 'MeshbluSocketIOHandler', ->
  beforeEach ->
    @meshbluEventEmitter = new EventEmitter

  describe 'initialize', ->
    beforeEach ->
      @sut = new MeshbluSocketIOHandler meshbluEventEmitter: @meshbluEventEmitter
      @socket = new EventEmitter
      @sut.initialize @socket

    it 'should set @socket', ->
      expect(@sut.socket).to.deep.equal @socket

  describe '->identity', ->
    describe 'when authDevice yields an error', ->
      beforeEach ->
        @socket = new EventEmitter

        @authDevice = sinon.stub().yields new Error 'not authorized'
        @sut = new MeshbluSocketIOHandler authDevice: @authDevice, meshbluEventEmitter: @meshbluEventEmitter
        @sut.initialize @socket
        @socket.emit 'identity', {uuid: 'something', token: 'something-else'}, (@result) =>

      it 'should call the callback with the error', ->
        [error,data] = @result

        expect(error).to.deep.equal message: 'not authorized', status: 401

    describe 'when authDevice dont yields an error, and do yield a device gud', ->
      beforeEach ->
        @socket = new EventEmitter

        @authDevice = sinon.stub().yields null, {uuid: 'device'}
        @sut = new MeshbluSocketIOHandler authDevice: @authDevice, meshbluEventEmitter: @meshbluEventEmitter
        @sut.initialize @socket
        @callback = sinon.spy()
        @socket.emit 'identity', uuid: 'device', token: 'wrong', @callback

      it 'should call authDevice', ->
        expect(@authDevice).to.have.been.calledWith 'device', 'wrong'

      it 'should call the callback with the device', ->
        expect(@callback).to.have.been.calledWith [null, {uuid: 'device'}]

    describe 'when authDevice dont yields an error, and do yield a device gud, an I dunt read too gud', ->
      beforeEach ->
        @socket = new EventEmitter

        @device = {some: 'device', uuid: '23955'}
        @authDevice = sinon.stub().yields null, @device
        @sut = new MeshbluSocketIOHandler authDevice: @authDevice, meshbluEventEmitter: @meshbluEventEmitter
        @sut.initialize @socket
        @callback = sinon.spy()
        @socket.emit 'identity', uuid: '23955', token: '$###', @callback

      it 'should call the callback with the device', ->
        expect(@callback).to.have.been.calledWith [null, {uuid: '23955'}]

      it 'should set authedDevice on the handler with the token', ->
        expect(@sut.authedDevice.uuid).to.equal '23955'
        expect(@sut.authedDevice.token).to.equal '$###'

  describe 'update', ->
    describe 'when authedDevice yields an error', ->
      beforeEach ->
        @socket = new EventEmitter

        @authDevice = sinon.stub().yields new Error

        @sut = new MeshbluSocketIOHandler authDevice: @authDevice, meshbluEventEmitter: @meshbluEventEmitter
        @sut.initialize @socket
        @sut = sinon.spy()

        @socket.emit 'update', [{uuid: '1345'}, {$set: {online: true}}], (@result) =>

      it 'should call the callback with an error', ->
        [error] = @result
        expect(error).to.deep.equal message: 'unauthorized', status: 403

    describe 'when authedDevice yields an null and a device', ->
      beforeEach ->
        @socket = new EventEmitter
        @onError = sinon.spy()
        @socket.on 'error', @onError

        @device = {uuid: '1345'}
        @authDevice = sinon.stub().yields null, @device
        @updateIfAuthorized = sinon.stub()

        @sut = new MeshbluSocketIOHandler authDevice: @authDevice, updateIfAuthorized: @updateIfAuthorized, meshbluEventEmitter: @meshbluEventEmitter
        @sut.initialize @socket
        @sut.authedDevice = uuid: '1345', token: 'toooooken'
        @sut = sinon.spy()

        @socket.emit 'update', [{uuid: '1345'}, {$set: {online: true}}], (@result) =>

      it 'should call authDevice', ->
        expect(@authDevice).to.have.been.calledWith '1345', 'toooooken'

      it 'should call updateIfAuthorized', ->
        expect(@updateIfAuthorized).to.have.been.calledWith @device, {uuid: '1345'}, {$set: {online: true}}

      describe 'when updateIfAuthorized yields an error', ->
        beforeEach ->
          @updateIfAuthorized.yield new Error('not acceptable')

        it 'should emit an error', ->
          expect(@updateIfAuthorized).to.have.been.calledWith @device, {uuid: '1345'}, {$set: {online: true}}

        it 'should call the callback with a result that contains an error', ->
          [error] = @result
          expect(error).to.deep.equal message: 'not acceptable', status: 422

      describe 'when updateIfAuthorized yields no error', ->
        beforeEach ->
          @updateIfAuthorized.yield
