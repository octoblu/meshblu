resetToken = require '../../lib/resetToken'

describe 'resetToken', ->
  beforeEach ->
    @securityImpl = {}
    @getDevice = sinon.stub()
    @device = resetToken: sinon.stub()
    @Device = sinon.spy =>
      @device
    @emitToClient = sinon.stub()

    #currying, yo
    @sut = (fromDevice, uuid, callback) =>
      resetToken fromDevice, uuid, @emitToClient, callback, {@securityImpl, @getDevice, @Device}

  it 'should exist', ->
    expect(@sut).to.exist

  describe 'when it is called with a fromDevice and a uuid', ->
    beforeEach ->
      @securityImpl.canConfigure = sinon.stub().yields null, false
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
        @theDevice = uuid: 'uuid', name: 'blah'
        @getDevice.yields null, @theDevice

      it 'should call securityImpl.canConfigure', ->
        @sut @fromDevice, 1
        expect(@securityImpl.canConfigure).to.have.been.called

      it 'should have been called with the device from getDevice and fromDevice', ->
        @sut @fromDevice, 'uuid'
        expect(@securityImpl.canConfigure).to.have.been.calledWith @fromDevice, @theDevice

      describe 'when securityImpl.canConfigure returns false', ->
        beforeEach ->
          @securityImpl.canConfigure.returns false

        it 'should call the callback with "unauthorized"', ->
          callback = sinon.spy()
          @sut @fromDevice, 3, callback
          expect(callback).to.have.been.calledWith 'unauthorized'

      describe 'when securityImpl.canConfigure returns true', ->
        beforeEach ->
          @securityImpl.canConfigure.yields null, true

        it 'should not call the callback with "unauthorized"', ->
          callback = sinon.spy()
          @sut @fromDevice, 3, callback
          expect(callback).to.not.have.been.calledWith 'unauthorized'

        it 'should call device.resetToken', ->
          @sut @fromDevice, 3
          expect(@device.resetToken).to.have.been.called

        describe 'when device.resetToken returns with an error', ->
          beforeEach ->
            @device.resetToken.yields true

          it 'should call the callback with an error', ->
            callback = sinon.spy()
            @sut @fromDevice, 3, callback
            expect(callback).to.be.calledWith 'error updating device'

        describe 'when device.resetToken returns without an error', ->
          beforeEach ->
            @device.resetToken.yields undefined, 'a-new-token'
          it 'should return a token', ->
            callback = sinon.spy()
            @sut @fromDevice, 3, callback
            expect(callback).to.be.calledWith null, 'a-new-token'

          it 'should call emitToClient', ->
            @sut @fromDevice, 3
            expect(@emitToClient).to.have.been.calledWith('notReady', @fromDevice)

  describe 'when it is called with a different fromDevice and uuid', ->
    beforeEach ->
      @fromDevice = a: 'different', one : 'true'
      @securityImpl.canConfigure = sinon.spy()
      @theDevice = uuid: '2', name: 'Koshin'
      @getDevice.yields null, @theDevice

    it 'should call getDevice with a different uuid', ->
      @sut @fromDevice, 2
      expect(@getDevice).to.have.been.calledWith 2

    it 'should call securityImpl.canConfigure with the different fromDevice & uuid', ->
      @sut @fromDevice, '2'
      expect(@securityImpl.canConfigure).to.have.been.calledWith @fromDevice, @theDevice
