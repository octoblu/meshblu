describe 'claimDevice', ->
  beforeEach ->
    @updateDevice = sinon.stub()
    @canConfigure = sinon.stub()
    @getDevice    = sinon.stub()
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

      @getDevice.yields null, {ipAddress: '192.168.1.1'}
      @updateDevice.yields null, @device
      @sut @fromDevice, @device, done, @dependencies

    it 'should call updateDevice with that uuid and name', ->
      expect(@updateDevice).to.have.been.calledWith @device.uuid, {owner: @fromDevice.uuid, uuid: @device.uuid, discoverWhitelist: [@fromDevice.uuid], ipAddress: '192.168.1.1'}

  describe 'when called with params other than uuid', ->
    beforeEach (done) ->
      @fromDevice = {uuid: '89e9cd5f-dfff-4771-b821-d35614b7a506'}
      @device     = {uuid: '07a4ed85-acc5-4495-b3d7-2d93439c04fa', name: 'Cookie Crisp'}

      @getDevice.yields null, {ipAddress: '192.168.1.1'}
      @updateDevice.yields null, @device
      @sut @fromDevice, @device, done, @dependencies

    it 'should call updateDevice with that uuid and name', ->
      expect(@updateDevice).to.have.been.calledWith @device.uuid, {owner: @fromDevice.uuid, name: 'Cookie Crisp', uuid: @device.uuid, discoverWhitelist: [@fromDevice.uuid], ipAddress: '192.168.1.1'}

  describe 'when called with an owner param', ->
    beforeEach (done) ->
      @fromDevice = {uuid: 'e33c1844-6888-4698-852a-7be584327a1d'}
      @device     = {uuid: '9b97159e-63c2-4a71-9327-8fadad97f1e9', name: 'Fruit Loops', owner: 'wrong'}

      @getDevice.yields null, {ipAddress: '192.168.1.1'}
      @updateDevice.yields null, @device
      @sut @fromDevice, @device, done, @dependencies

    it 'should call updateDevice with that uuid and name', ->
      expect(@updateDevice).to.have.been.calledWith @device.uuid, {owner: @fromDevice.uuid, name: 'Fruit Loops', uuid: @device.uuid, discoverWhitelist: [@fromDevice.uuid], ipAddress: '192.168.1.1'}

  describe 'when called by a non-authorized user', ->
    beforeEach (done) ->
      @fromDevice = {uuid: '1267b0fe-407a-4872-b09d-dd4853d59d76'}
      @device     = {uuid: '9b97159e-63c2-4a71-9327-8fadad97f1e9', name: 'Fruit Loops'}

      storeError = (@error) => done()

      @canConfigure.returns false
      @getDevice.yields null, {ipAddress: '192.168.1.1'}
      @sut @fromDevice, @device, storeError, @dependencies

    it 'should call canConfigure with fromDevice, device with the ipAddress mixed in', ->
      expect(@canConfigure).to.have.been.calledWith @fromDevice, {
        uuid: '9b97159e-63c2-4a71-9327-8fadad97f1e9'
        ipAddress: '192.168.1.1'
        name: 'Fruit Loops'
      }

    it 'should not call updateDevice with that uuid and name', ->
      expect(@updateDevice).not.to.have.been.called

    it 'should call the callback with an error', ->
      expect(@error).to.exist
