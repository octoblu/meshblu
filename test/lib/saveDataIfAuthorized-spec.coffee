saveDataIfAuthorized = require '../../lib/saveDataIfAuthorized'
_ = require 'lodash'

describe 'saveDataIfAuthorized', ->
  describe 'when called with data', ->
    beforeEach ->
      @sut = saveDataIfAuthorized

      @toDevice     = {uuid: 'to-device', sendWhitelist: ['from-device']}
      @getDevice    = sinon.stub().yields null, @toDevice
      @canSend = sinon.stub()
      @logEvent = sinon.stub()
      @sendMessage = sinon.stub()
      @moment = toISOString: sinon.stub().returns('a very important date')
      @Moment = sinon.spy => @moment

      @dataDB = insert: sinon.stub()
      @sendConfigActivity = sinon.spy()

      @dependencies = getDevice: @getDevice, securityImpl: {canSend: @canSend}, dataDB: @dataDB, logEvent: @logEvent, moment: @Moment

      @callback = sinon.spy()
      @sut @sendMessage, {uuid: 'from-device'}, 'to-device', {something: 'awful'}, @callback, @dependencies

    it 'should call canSend with the fromDevice, the toDevice and the query', ->
      expect(@canSend).to.have.been.calledWith {uuid: 'from-device'}, @toDevice, {something: 'awful'}

    describe 'when canSend yields an error', ->
      beforeEach ->
        @canSend.yield new Error('Something really, really bad happened')

      it 'should call the callback with the error', ->
        expect(@callback).to.have.been.called

        error = @callback.firstCall.args[0]
        expect(error).to.be.an.instanceOf Error
        expect(error.message).to.deep.equal 'Something really, really bad happened'

    describe 'when canSend yields false', ->
      beforeEach ->
        @canSend.yield null, false

      it 'should yield an error', ->
        expect(@callback).to.have.been.called

        error = @callback.firstCall.args[0]
        expect(error).to.be.an.instanceOf Error
        expect(error.message).to.deep.equal 'Device does not have sufficient permissions to save data'

    describe 'when canSend yields true', ->
      beforeEach ->
        @canSend.yield null, true

      it 'should not have called the callback yet', ->
        expect(@callback).to.have.not.been.called #yet

      it 'should call logEvent with the uuid', ->
        expect(@logEvent).to.have.been.calledWith 700, something: 'awful', timestamp: "a very important date", uuid: "to-device"

      it 'should call insert on the database', ->
        expect(@dataDB.insert).to.have.been.calledWith {something: 'awful', timestamp: "a very important date", uuid: "to-device"}

      describe 'when insert yields an error', ->
        beforeEach ->
          @dataDB.insert.yield new Error('device failed to update')

        it 'should call the callback with the error', ->
          expect(@callback).to.have.been.called

          error = @callback.firstCall.args[0]
          expect(error).to.be.an.instanceOf Error
          expect(error.message).to.deep.equal 'device failed to update'

      describe 'when insert yields no error', ->
        beforeEach ->
          @dataDB.insert.yield null, true

        it 'should call sendMessage', ->
          expect(@sendMessage).to.have.been.calledWith { sendWhitelist: ["from-device"], uuid: "to-device" }, devices: ['*'], payload: {something: 'awful', timestamp: "a very important date", uuid: "to-device"}

        it 'should call the callback without an error', ->
          expect(@callback).to.have.been.called

          error = @callback.firstCall.args[0]
          saved = @callback.firstCall.args[1]
          expect(error).not.to.be
          expect(saved).to.be.true
