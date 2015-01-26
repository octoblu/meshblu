describe 'getPublicKey', ->
  beforeEach ->
    @sut = require '../../lib/getPublicKey'

  describe 'when called with (almost) nothing', ->
    beforeEach (done) ->
      storeError = (@error) => done()
      @sut null, storeError

    it 'should call done with an error', ->
      expect(@error.message).to.equal 'uuid is required for public key lookup'

  describe 'when the device does not exist', ->
    beforeEach (done) ->
      @getDevice = sinon.stub().yields null, null
      storeResult = (@error, @publicKey) => done()
      @sut '3ba8e966-1835-4e36-bfc2-90d70f9305a9', storeResult, getDevice: @getDevice

    it 'should return null', ->
      expect(@publicKey).to.be.null

    it 'should call getDevice with the uuid', ->
      expect(@getDevice).to.have.been.calledWith '3ba8e966-1835-4e36-bfc2-90d70f9305a9'

  describe 'when yet another device does not exist', ->
    beforeEach (done) ->
      @getDevice = sinon.stub().yields null, null
      storeResult = (@error, @publicKey) => done()
      @sut '79b20d9f-2de2-4ce2-ae44-8b0bb68f4f21', storeResult, getDevice: @getDevice

    it 'should return null', ->
      expect(@publicKey).to.be.null

    it 'should call getDevice with the uuid', ->
      expect(@getDevice).to.have.been.calledWith '79b20d9f-2de2-4ce2-ae44-8b0bb68f4f21'

  describe 'when the device does exist', ->
    beforeEach (done) ->
      @getDevice = sinon.stub().yields null, {publicKey: 'shhhh, secrets'}
      storeResult = (@error, @publicKey) => done()
      @sut 'db34cd53-c1ab-4da6-919f-9c7359142905', storeResult, getDevice: @getDevice

    it 'should return the super secret', ->
      expect(@publicKey).to.equal 'shhhh, secrets'

    it 'should call getDevice with the uuid', ->
      expect(@getDevice).to.have.been.calledWith 'db34cd53-c1ab-4da6-919f-9c7359142905'

  describe 'when fetching the device errors', ->
    beforeEach (done) ->
      @getDevice = sinon.stub().yields new Error("I can't let you do that")
      storeResult = (@error, @publicKey) => done()
      @sut 'db34cd53-c1ab-4da6-919f-9c7359142905', storeResult, getDevice: @getDevice

    it 'should return the super secret', ->
      expect(@error.message).to.equal "I can't let you do that"

    it 'should call getDevice with the uuid', ->
      expect(@getDevice).to.have.been.calledWith 'db34cd53-c1ab-4da6-919f-9c7359142905'
