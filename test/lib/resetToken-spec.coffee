resetToken = require '../../lib/resetToken'

describe 'resetToken', ->
  beforeEach ->    
    @securityImpl = {}
    @getDevice = sinon.stub()
    @updateDevice = sinon.stub()

    #currying, yo
    @sut = (fromDevice, uuid, callback) =>
      resetToken fromDevice, uuid, callback, @securityImpl, @getDevice, @updateDevice

  it 'should exist', ->
    expect(@sut).to.exist

  describe 'when it is called with a fromDevice and a uuid', ->
    beforeEach ->
      @securityImpl.canConfigure = sinon.stub()
      @fromDevice = {}

    it 'should call getDevice', ->
      @sut @fromDevice, 1
      expect(@getDevice).to.have.been.called

    it 'should call getDevice with the uuid', ->
      @sut @fromDevice, 1
      expect(@getDevice).to.have.been.calledWith 1

    describe 'when getDevice yields an error', ->
      beforeEach ->
        @getDevice.yields true, null

      it 'should call our callback with the error "invalid device"', ->
        callback = sinon.spy()
        @sut @fromDevice, 1, callback
        expect(callback).to.be.calledWith 'invalid device'

      it 'should not call securityImpl.canConfigure', ->
        @sut @fromDevice, 1, ->
        expect(@securityImpl.canConfigure).to.not.have.been.called

    describe 'when getDevice returns a device', ->
      beforeEach ->
        @device = uuid: 'uuid', name: 'blah'
        @getDevice.yields null, @device

      it 'should call securityImpl.canConfigure', -> 
        @sut @fromDevice, 1     
        expect(@securityImpl.canConfigure).to.have.been.called

      it 'should have been called with the device from getDevice and fromDevice', ->
        @sut @fromDevice, 'uuid'
        expect(@securityImpl.canConfigure).to.have.been.calledWith @fromDevice, @device

      describe 'when securityImpl.canConfigure returns false', ->
        beforeEach ->
          @securityImpl.canConfigure.returns false

        it 'should call the callback with "unauthorized"', ->
          callback = sinon.spy()
          @sut @fromDevice, 3, callback
          expect(callback).to.have.been.calledWith 'unauthorized'

      describe 'when securityImpl.canConfigure returns true', ->
        beforeEach ->
          @securityImpl.canConfigure.returns true
        
        it 'should not call the callback with "unauthorized"', ->
          callback = sinon.spy()
          @sut @fromDevice, 3, callback
          expect(callback).to.not.have.been.calledWith 'unauthorized'

        it 'should call updateDevice', ->
          @sut @fromDevice, 3
          expect(@updateDevice).to.have.been.called

        it 'should call updateDevice with the toDevice uuid and parameters containing a token', ->
          @sut @fromDevice, 3
          args = @updateDevice.args[0]
          expect(args[0]).to.equal @device.uuid
          expect(args[1].token).to.exist

        it 'should update the device with a token greater than 20 characters long', ->
          @sut @fromDevice, 3
          args = @updateDevice.args[0]
          expect(args[1].token.length).to.be.greaterThan 20
          expect(args[1].token).to.be.a 'string'

        it 'should update the device with a different token each time it is called', ->
          @sut @fromDevice, 3
          args = @updateDevice.args[0]
          token = args[1].token
          @sut @fromDevice, 3
          args = @updateDevice.args[1]
          
          expect(token).to.not.deep.equal(args[1].token)

        describe 'when updateDevice returns with an error', ->
          beforeEach ->
            @updateDevice.yields true

          it 'should call the callback with an error', ->
            callback = sinon.spy()
            @sut @fromDevice, 3, callback
            expect(callback).to.be.calledWith 'error updating device'

        describe 'when updateDevice returns without an error', ->
          beforeEach ->
            @updateDevice.yields undefined, @fromDevice

          it 'should return a token', ->
            callback = sinon.spy()
            @sut @fromDevice, 3, callback
            expect(callback).to.be.calledWith null, @updateDevice.args[0][1].token

  describe 'when it is called with a different fromDevice and uuid', ->
    beforeEach ->
      @fromDevice = a: 'different', one : 'true'
      @securityImpl.canConfigure = sinon.spy()
      @device = uuid: '2', name: 'Koshin'
      @getDevice.yields null, @device

    it 'should call getDevice with a different uuid', ->
      @sut @fromDevice, 2
      expect(@getDevice).to.have.been.calledWith 2

    it 'should call securityImpl.canConfigure with the different fromDevice & uuid', ->      
      @sut @fromDevice, '2'
      expect(@securityImpl.canConfigure).to.have.been.calledWith @fromDevice, @device