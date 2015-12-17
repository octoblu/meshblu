describe 'doMessageHooks', ->
  beforeEach ->
    @device = {}
    @messageWebhook = send: sinon.stub()
    @MessageWebhook = sinon.spy => @messageWebhook

    @dependencies = MessageWebhook: @MessageWebhook
    @sut = require '../../lib/doMessageHooks'

  describe 'when called with null hook', ->
    beforeEach (done) ->
      ignoreErrors = => done()
      @sut(@device, null, payload: 'You got old', ignoreErrors, @dependencies)

    it 'should not instantiate a MessageWebhook', ->
      expect(@MessageWebhook).not.to.have.been.called

  describe 'when called with one hook, and MessageWebhook yields', ->
    beforeEach (done) ->
      @messageWebhook.send.yields null
      ignoreErrors = => done()
      @sut(@device, [name: 'Rufio'], payload: 'You got old', ignoreErrors, @dependencies)

    it 'should instantiate a MessageWebhook', ->
      options =
        uuid: @device.uuid
        options: name: 'Rufio'

      expect(@MessageWebhook).to.have.been.calledWith options
      expect(@MessageWebhook).to.have.been.alwaysCalledWithNew

    it 'should call send on the messageWebhook', ->
      expect(@messageWebhook.send).to.have.been.calledOnce
      expect(@messageWebhook.send).to.have.been.calledWith payload: 'You got old'

  describe 'when called with two hooks and messageWebhook yields', ->
    beforeEach (done) ->
      @messageWebhook.send.yields null
      ignoreErrors = => done()
      @sut(@device, [{uuid: 'hook', fromUuid: 'smee'}, {uuid: 'toodles', fromUuid: 'smee'}], {payload: "I've just had an apostrophe"}, ignoreErrors, @dependencies)

    it 'should instantiate a MessageWebhook(s)', ->
      expect(@MessageWebhook).to.have.been.alwaysCalledWithNew
      expect(@MessageWebhook.firstCall.args[0].options).to.deep.equal {uuid: 'hook', fromUuid: 'smee'}
      expect(@MessageWebhook.secondCall.args[0].options).to.deep.equal {uuid: 'toodles', fromUuid: 'smee'}

    it 'should call send on the messageWebhook', ->
      expect(@messageWebhook.send).to.have.been.calledTwice
      expect(@messageWebhook.send).to.have.been.always.calledWith {payload: "I've just had an apostrophe"}

  describe 'when the first messageWebhook.send yields an error', ->
    beforeEach (done) ->
      @messageWebhook.send.yields new Error("I've lost my marbles.")
      storeError = (@errors) => done()
      @sut @device, [{}], {}, storeError, @dependencies

    it 'should yield an error', ->
      error = @errors[0]
      expect(error).to.be.an.instanceOf Error
      expect(error.message).to.deep.equal "I've lost my marbles."

  describe 'when none of the sends yield', ->
    beforeEach ->
      @callback = sinon.spy()
      @sut @device, [{}, {}], {}, @callback, @dependencies

    it 'should not call its callback', ->
      expect(@callback).to.not.have.been.called
