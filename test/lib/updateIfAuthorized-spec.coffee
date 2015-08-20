updateIfAuthorized = require '../../lib/updateIfAuthorized'
_ = require 'lodash'

describe 'updateIfAuthorized', ->
  describe 'when called with a device', ->
    beforeEach ->
      @sut = updateIfAuthorized

      @toDevice     = {uuid: 'to-device', configureWhitelist: ['from-device']}
      @getDevice    = sinon.stub().yields null, @toDevice
      @canConfigure = sinon.stub()
      @clearCache = sinon.stub().yields null

      @device = update: sinon.stub()
      @Device = sinon.spy => @device
      @sendConfigActivity = sinon.spy()

      @dependencies = getDevice: @getDevice, securityImpl: {canConfigure: @canConfigure}, Device: @Device, clearCache: @clearCache, sendConfigActivity: @sendConfigActivity

      @callback = sinon.spy()
      @sut {uuid: 'from-device'}, {uuid: 'to-device', token: 'token'}, {$inc: {magic: 1}}, @callback, @dependencies


    it 'should call canConfigure with the fromDevice, the toDevice and the query', ->
      expect(@canConfigure).to.have.been.calledWith {uuid: 'from-device'}, @toDevice, {uuid: 'to-device', token: 'token'}

    describe 'when canConfigure yields an error', ->
      beforeEach ->
        @canConfigure.yield new Error('Something really, really bad happened')

      it 'should call the callback with the error', ->
        expect(@callback).to.have.been.called

        error = @callback.firstCall.args[0]
        expect(error).to.be.an.instanceOf Error
        expect(error.message).to.deep.equal 'Something really, really bad happened'

    describe 'when canConfigure yields false', ->
      beforeEach ->
        @canConfigure.yield null, false

      it 'should yield an error', ->
        expect(@callback).to.have.been.called

        error = @callback.firstCall.args[0]
        expect(error).to.be.an.instanceOf Error
        expect(error.message).to.deep.equal 'Device does not have sufficient permissions for update'

    describe 'when canConfigure yields true', ->
      beforeEach ->
        @canConfigure.yield null, true

      it 'should not have called the callback yet', ->
        expect(@callback).to.have.not.been.called #yet

      it 'should call clearCache with the uuid', ->
        expect(@clearCache).to.have.been.calledWith 'to-device'

      it 'should instantiate a Device', ->
        expect(@Device).to.have.been.calledWithNew
        expect(@Device).to.have.been.calledWith uuid: 'to-device'

      it 'should call update on the device', ->
        expect(@device.update).to.have.been.calledWith {$inc: {magic: 1}}

      describe 'when update yields no error', ->
        beforeEach ->
          @device.update.yield null

        it 'should call sendConfigActivity', ->
          expect(@sendConfigActivity).to.have.been.calledWith 'to-device'

      describe 'when update yields an error', ->
        beforeEach ->
          @device.update.yield new Error('device failed to update')

        it 'should call the callback with the error', ->
          expect(@callback).to.have.been.called

          error = @callback.firstCall.args[0]
          expect(error).to.be.an.instanceOf Error
          expect(error.message).to.deep.equal 'device failed to update'

  describe 'when called with another device', ->
    beforeEach ->
      @sut = updateIfAuthorized

      @toDevice     = {uuid: 'uuid', configureWhitelist: ['from-device']}
      @getDevice    = sinon.stub().yields null, @toDevice
      @canConfigure = sinon.stub()
      @clearCache = sinon.stub().yields null

      @device = update: sinon.spy()
      @Device = sinon.spy => @device

      @dependencies = getDevice: @getDevice, securityImpl: {canConfigure: @canConfigure}, Device: @Device, clearCache: @clearCache

      callback = (@error) =>
      @sut {uuid: 'from-device'}, {uuid: 'uuid', token: 'token'}, null, callback, @dependencies

    describe 'when canConfigure yields true', ->
      beforeEach ->
        @canConfigure.yield null, true

      it 'should instantiate a Device', ->
        expect(@Device).to.have.been.calledWithNew
        expect(@Device).to.have.been.calledWith uuid: 'uuid'
