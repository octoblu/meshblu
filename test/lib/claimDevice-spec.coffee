describe 'claimDevice', ->
  beforeEach ->
    @updateDevice = sinon.stub()
    @canConfigure = sinon.stub()
    @canConfigure.returns true
    @dependencies = {updateDevice: @updateDevice, canConfigure: @canConfigure, getDevice: @getDevice}
    @sut = require '../../lib/claimDevice'

  it 'should be a function', ->
    expect(@sut).to.be.a 'function'

  describe 'when called with a bunch of nothing', ->
    beforeEach (done) ->
      storeError = (@error) => done()
      @sut null, null, storeError, @dependencies

    it 'should callback with an error', ->
      expect(@error).to.exist

  describe 'when called with a some of nothing', ->
    beforeEach (done) ->
      storeError = (@error) => done()
      @sut {uuid: 'something'}, null, storeError, @dependencies

    it 'should callback with an error', ->
      expect(@error).to.exist

  describe 'when called with a bunch of something', ->
    beforeEach (done) ->
      @fromDevice = {uuid: '89e9cd5f-dfff-4771-b821-d35614b7a506'}
      @device     = {uuid: '07a4ed85-acc5-4495-b3d7-2d93439c04fa'}

      @updateDevice.yields null, @device
      @sut @fromDevice, @device, done, @dependencies

    it 'should call updateDevice with that uuid and name', ->
      expect(@updateDevice).to.have.been.calledWith @device.uuid, {owner: @fromDevice.uuid, uuid: @device.uuid, discoverWhitelist: [@fromDevice.uuid]}

  describe 'when called with params other than uuid', ->
    beforeEach (done) ->
      @fromDevice = {uuid: '89e9cd5f-dfff-4771-b821-d35614b7a506'}
      @device     = {uuid: '07a4ed85-acc5-4495-b3d7-2d93439c04fa', name: 'Cookie Crisp'}

      @updateDevice.yields null, @device
      @sut @fromDevice, @device, done, @dependencies

    it 'should call updateDevice with that uuid and name', ->
      expect(@updateDevice).to.have.been.calledWith @device.uuid, {owner: @fromDevice.uuid, name: 'Cookie Crisp', uuid: @device.uuid, discoverWhitelist: [@fromDevice.uuid]}

  describe 'when called with an owner param', ->
    beforeEach (done) ->
      @fromDevice = {uuid: 'e33c1844-6888-4698-852a-7be584327a1d'}
      @device     = {uuid: '9b97159e-63c2-4a71-9327-8fadad97f1e9', name: 'Fruit Loops', owner: 'wrong'}

      @updateDevice.yields null, @device
      @sut @fromDevice, @device, done, @dependencies

    it 'should call updateDevice with that uuid and name', ->
      expect(@updateDevice).to.have.been.calledWith @device.uuid, {owner: @fromDevice.uuid, name: 'Fruit Loops', uuid: @device.uuid, discoverWhitelist: [@fromDevice.uuid]}

  describe 'when called by a non-authorized user', ->
    beforeEach (done) ->
      @fromDevice = {uuid: '1267b0fe-407a-4872-b09d-dd4853d59d76'}
      @device     = {uuid: '9b97159e-63c2-4a71-9327-8fadad97f1e9', name: 'Fruit Loops', owner: 'wrong'}

      storeError = (@error) => done()

      @canConfigure.returns false
      @sut @fromDevice, @device, storeError, @dependencies

    it 'should call canConfigure with fromDevice, toDevice, and data', ->
      expect(@canConfigure).to.have.been.calledWith @fromDevice, @device

    it 'should not call updateDevice with that uuid and name', ->
      expect(@updateDevice).not.to.have.been.called

    it 'should call the callback with an error', ->
      expect(@error).to.exist
