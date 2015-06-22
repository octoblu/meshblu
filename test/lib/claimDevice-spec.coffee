describe 'claimDevice', ->
  beforeEach ->
    @oldUpdateDevice = sinon.stub()
    @canConfigure = sinon.stub()
    @getDeviceWithToken    = sinon.stub()
    @canConfigure.yields null, true
    @dependencies = {oldUpdateDevice: @oldUpdateDevice, canConfigure: @canConfigure, getDeviceWithToken: @getDeviceWithToken}
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

      @getDeviceWithToken.yields null, {uuid: '07a4ed85-acc5-4495-b3d7-2d93439c04fa', ipAddress: '192.168.1.1'}
      @oldUpdateDevice.yields null, @device
      @sut @fromDevice, @device, done, @dependencies

    it 'should call oldUpdateDevice with that uuid and name', ->
      expect(@oldUpdateDevice).to.have.been.deep.calledWith @device.uuid, {
        owner: @fromDevice.uuid
        uuid: @device.uuid
        discoverWhitelist: [
          @fromDevice.uuid
        ]
        configureWhitelist: [
          @fromDevice.uuid
        ]
        ipAddress: '192.168.1.1'
      }

  describe 'when called with params other than uuid', ->
    beforeEach (done) ->
      @fromDevice = {uuid: '89e9cd5f-dfff-4771-b821-d35614b7a506'}
      @device     = {uuid: '07a4ed85-acc5-4495-b3d7-2d93439c04fa', name: 'Cookie Crisp'}

      @getDeviceWithToken.yields null, {name: 'Cookie Crisp', uuid: '07a4ed85-acc5-4495-b3d7-2d93439c04fa', ipAddress: '192.168.1.1'}
      @oldUpdateDevice.yields null, @device
      @sut @fromDevice, @device, done, @dependencies

    it 'should call oldUpdateDevice with that uuid and name', ->
      expect(@oldUpdateDevice).to.have.been.calledWith @device.uuid, {
        owner: @fromDevice.uuid
        name: 'Cookie Crisp'
        uuid: @device.uuid
        discoverWhitelist: [
          @fromDevice.uuid
        ]
        configureWhitelist: [
          @fromDevice.uuid
        ]
        ipAddress: '192.168.1.1'
      }

  describe 'when called with an owner param', ->
    beforeEach (done) ->
      @fromDevice = {uuid: 'e33c1844-6888-4698-852a-7be584327a1d'}
      @device     = {uuid: '9b97159e-63c2-4a71-9327-8fadad97f1e9', name: 'Fruit Loops', owner: 'wrong'}

      @getDeviceWithToken.yields null, {name: 'Fruit Loops', uuid: '9b97159e-63c2-4a71-9327-8fadad97f1e9', ipAddress: '192.168.1.1'}
      @oldUpdateDevice.yields null, @device
      @sut @fromDevice, @device, done, @dependencies

    it 'should call oldUpdateDevice with that uuid and name', ->
      expect(@oldUpdateDevice).to.have.been.calledWith @device.uuid, {
        owner: @fromDevice.uuid
        name: 'Fruit Loops'
        uuid: @device.uuid
        discoverWhitelist: [
          @fromDevice.uuid
        ]
        configureWhitelist: [
          @fromDevice.uuid
        ]
        ipAddress: '192.168.1.1'
      }

  describe 'when called by an unauthorized user', ->
    beforeEach (done) ->
      @fromDevice = {uuid: '1267b0fe-407a-4872-b09d-dd4853d59d76'}
      @device     = {uuid: '9b97159e-63c2-4a71-9327-8fadad97f1e9', name: 'Fruit Loops'}

      storeError = (@error) => done()

      @canConfigure.yields null, false
      @getDeviceWithToken.yields null, {uuid: '9b97159e-63c2-4a71-9327-8fadad97f1e9', name: 'Fruit Loops', ipAddress: '192.168.1.1'}
      @sut @fromDevice, @device, storeError, @dependencies

    it 'should call canConfigure with fromDevice, device with the ipAddress mixed in', ->
      expect(@canConfigure).to.have.been.calledWith @fromDevice, {
        uuid: '9b97159e-63c2-4a71-9327-8fadad97f1e9'
        ipAddress: '192.168.1.1'
        name: 'Fruit Loops'
      }

    it 'should not call oldUpdateDevice with that uuid and name', ->
      expect(@oldUpdateDevice).not.to.have.been.called

    it 'should call the callback with an error', ->
      expect(@error).to.exist

  describe 'when called', ->
    beforeEach (done) ->
      fromDevice = {uuid: '1267b0fe-407a-4872-b09d-dd4853d59d76'}
      device     = {uuid: '9b97159e-63c2-4a71-9327-8fadad97f1e9'}

      storeError = (@error) => done()

      @notFoundError = new Error 'Device not found'
      @getDeviceWithToken.yields @notFoundError, null
      @sut fromDevice, device, storeError, @dependencies

    it 'should call yield the device not found error', ->
      expect(@error).to.equal @notFoundError
