updateIfAuthorized = require '../../lib/updateIfAuthorized'
_ = require 'lodash'

describe 'updateIfAuthorized', ->
  describe 'when called with a device', ->
    beforeEach ->
      @sut = updateIfAuthorized

      @toDevice     = {uuid: 'to-device', configureWhitelist: ['from-device']}
      @canConfigure = sinon.stub()

      @device =
        update: sinon.stub()
        fetch: sinon.stub()

      @Device = sinon.spy => @device

      @dependencies = securityImpl: {canConfigure: @canConfigure}, Device: @Device

      @callback = sinon.spy()
      @sut {uuid: 'from-device'}, {uuid: 'to-device', token: 'token'}, {$inc: {magic: 1}}, @callback, @dependencies

      @device.fetch.yield null, @toDevice

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

      it 'should instantiate a Device', ->
        expect(@Device).to.have.been.calledWithNew
        expect(@Device).to.have.been.calledWith uuid: 'to-device'

      it 'should call update on the device', ->
        expect(@device.update).to.have.been.calledWith {$inc: {magic: 1}}

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
      @canConfigure = sinon.stub()

      @device =
        update: sinon.spy()
        fetch: sinon.stub()

      @device.fetch.yields null, @toDevice
      @Device = sinon.spy => @device

      @dependencies = securityImpl: {canConfigure: @canConfigure}, Device: @Device

      callback = (@error) =>
      @sut {uuid: 'from-device'}, {uuid: 'uuid', token: 'token'}, null, callback, @dependencies

    describe 'when canConfigure yields true', ->
      beforeEach ->
        @canConfigure.yield null, true

      it 'should instantiate a Device', ->
        expect(@Device).to.have.been.calledWithNew
        expect(@Device).to.have.been.calledWith uuid: 'uuid'

  describe 'when called with a device and a list of uuids the config is forwarded for', ->
    beforeEach ->
      @forwardedFor = ['Fred', 'Barney']
      @sut = updateIfAuthorized
      @toDevice     = {uuid: 'to-device', configureWhitelist: ['from-device']}
      @canConfigure = sinon.stub().yields null, true

      @device =
        update: sinon.stub().yields null
        fetch: sinon.stub().yields null, @toDevice

      @Device = sinon.spy => @device

      @dependencies = securityImpl: {canConfigure: @canConfigure}, Device: @Device

      @callback = sinon.spy()
      fromDevice = {uuid: 'from-device'}
      query = {uuid: 'to-device', token: 'token'}
      update = {$inc: {magic: 1}}
      options = {forwardedFor: @forwardedFor}

      @sut(fromDevice, query, update, options, @callback, @dependencies)

      @device.fetch.yield null, @toDevice

    it 'should call update on the device with options containing the uuids the config was forwarded for', ->
      expect(@device.update).to.have.been.calledWith {$inc: {magic: 1}}, forwardedFor: @forwardedFor
