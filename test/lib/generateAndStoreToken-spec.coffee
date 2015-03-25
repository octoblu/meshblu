generateAndStoreToken = require '../../lib/generateAndStoreToken'

describe 'generateAndStoreToken', ->
  beforeEach ->
    @sut = generateAndStoreToken

  describe 'when called with a uuid and a callback', ->
    beforeEach (done) ->
      Device = sinon.spy()
      Device::generateToken = => 'charizard'
      Device::storeToken = sinon.stub().yields null

      @getDevice = sinon.stub().yields null, uuid: 'ccc2f14f-3a64-4aa0-b64c-8e62fbd52eaa'
      @securityImpl = canConfigure: => true

      @dependencies = Device: Device, getDevice: @getDevice, securityImpl: @securityImpl
      storeResults = (@error, @result) => done()

      @sut {uuid: '12'}, 'ccc2f14f-3a64-4aa0-b64c-8e62fbd52eaa', storeResults, @dependencies

    it 'should return no error', ->
      expect(@error).to.not.exist

    it 'should have a token in the result', ->
      expect(@result.token).to.equal 'charizard'

    it 'should instantiate a Device with the uuid', ->
      expect(@dependencies.Device).to.have.been.calledWith uuid: 'ccc2f14f-3a64-4aa0-b64c-8e62fbd52eaa'

    it 'should store the token', ->
      expect(@dependencies.Device::storeToken).to.have.been.calledWith 'charizard'


  describe 'when called with a different uuid and a callback', ->
    beforeEach (done) ->
      Device = sinon.stub()
      Device::generateToken = => 'pikachu'
      Device::storeToken = sinon.stub().yields null

      @getDevice = sinon.stub().yields null, uuid: '267fb089-1d2e-46cb-be13-9de4e75db441'
      @securityImpl = canConfigure: => true

      @dependencies = Device: Device, getDevice: @getDevice, securityImpl: @securityImpl
      storeResults = (@error, @result) => done()

      @sut {}, '267fb089-1d2e-46cb-be13-9de4e75db441', storeResults, @dependencies

    it 'should have a token in the result', ->
      expect(@result.token).to.equal 'pikachu'

    it 'should instantiate a Device with the uuid', ->
      expect(@dependencies.Device).to.have.been.calledWith uuid: '267fb089-1d2e-46cb-be13-9de4e75db441'

    it 'should store the token', ->
      expect(@dependencies.Device::storeToken).to.have.been.calledWith 'pikachu'

  describe 'called when storeResults yields an error', ->
    beforeEach (done) ->
      Device = sinon.spy()
      Device::generateToken = => 'charizard'
      Device::storeToken = sinon.stub().yields new Error()

      @getDevice = sinon.stub().yields null, uuid: 'ccc2f14f-3a64-4aa0-b64c-8e62fbd52eaa'
      @securityImpl = canConfigure: => true

      @dependencies = Device: Device, getDevice: @getDevice, securityImpl: @securityImpl
      storeResults = (@error, @result) => done()

      @sut {}, 'ccc2f14f-3a64-4aa0-b64c-8e62fbd52eaa', storeResults, @dependencies

    it 'should yield the error', ->
      expect(@error).to.exist

    it 'should have no result', ->
      expect(@result).to.not.exist

  describe 'when securityImp.canConfigure returns false', ->
    beforeEach (done) ->
      Device = sinon.spy()
      Device::generateToken = => 'charizard'

      @getDevice = sinon.stub().yields null, uuid: 'ccc2f14f-3a64-4aa0-b64c-8e62fbd52eaa'
      @securityImpl = canConfigure: => false

      @dependencies = Device: Device, getDevice: @getDevice, securityImpl: @securityImpl
      storeResults = (@error, @result) => done()

      @sut {}, 'ccc2f14f-3a64-4aa0-b64c-8e62fbd52eaa', storeResults, @dependencies

    it 'should yield the error', ->
      expect(@error).to.exist

    it 'should have no result', ->
      expect(@result).to.not.exist
