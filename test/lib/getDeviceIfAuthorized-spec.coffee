getDeviceIfAuthorized = require '../../lib/getDeviceIfAuthorized'

describe 'getDeviceIfAuthorized', ->
  describe 'when called with a device', ->
    beforeEach ->
      @sut = getDeviceIfAuthorized

      @toDevice     = {uuid: 'to-device', configureWhitelist: ['from-device']}
      @getDevice    = sinon.stub().yields null, @toDevice
      @canDiscover = sinon.stub()

      @dependencies = getDevice: @getDevice, securityImpl: {canDiscover: @canDiscover}

      @callback = sinon.spy()
      @sut {uuid: 'from-device'}, {uuid: 'to-device', token: 'token'}, @callback, @dependencies

    it 'should call canDiscover with the fromDevice, the toDevice and the query', ->
      expect(@canDiscover).to.have.been.calledWith {uuid: 'from-device'}, @toDevice, {uuid: 'to-device', token: 'token'}

    describe 'when canDiscover yields an error', ->
      beforeEach ->
        @canDiscover.yield new Error('unauthorized')

      it 'should yield the error', ->
        expect(@callback).to.have.been.calledWith new Error

    describe 'when canDiscover yields no error and a false', ->
      beforeEach ->
        @canDiscover.yield null, false

      it 'should yield an error', ->
        expect(@callback).to.have.been.calledWith new Error

    describe 'when canDiscover yields no error and true', ->
      beforeEach ->
        @canDiscover.yield null, true

      it 'should yield the toDevice', ->
        expect(@callback).to.have.been.calledWith null, @toDevice
