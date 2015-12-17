PublishForwarder = require '../src/publish-forwarder'
TestDatabase = require './test-database'

describe 'PublishForwarder', ->
  beforeEach (done) ->
    TestDatabase.open (error, database) =>
      {@devices,@subscriptions}  = database
      @devices.find {}, (error, devices) =>
        done error

  beforeEach ->
    @publisher = publish: sinon.stub().yields null
    @messageWebhook = send: sinon.stub().yields null
    @MessageWebhook = sinon.spy =>
      @messageWebhook
    @sut = new PublishForwarder {@publisher}, {@devices, @MessageWebhook, @subscriptions}

  describe '-> forward', ->
    beforeEach (done) ->
      @receiverUuid = 'dc8331b5-33b6-47b0-85db-2106930d0601'
      record =
        name: 'Receiver'
        uuid: @receiverUuid
      @devices.insert record, done

    context 'sent', ->
      context 'with a subscription', ->
        beforeEach (done) ->
          @forwarderUuid = '9749b660-b6dc-4189-b248-1248e72ecb51'
          record =
            name: 'Forwarder'
            uuid: @forwarderUuid
            configureWhitelist: [ @receiverUuid ]
          @devices.insert record, done

        beforeEach (done) ->
          record =
            emitterUuid: @forwarderUuid
            subscriberUuid: @receiverUuid
            type: 'sent'
          @subscriptions.insert record, done

        beforeEach (done) ->
          uuid = @forwarderUuid
          type = 'sent'
          message =
            devices: ['*']
          @sut.forward {uuid, type, message}, (error) =>
            done error

        it 'should forward a message', ->
          newMessage =
            devices: ['*']
            forwardedFor: [@forwarderUuid]

          expect(@publisher.publish).to.have.been.calledWith 'sent', @receiverUuid, newMessage

      context 'type: webhook', ->
        beforeEach (done) ->
          @hookOptions =
            type: 'webhook'
            url: 'http://example.com'
          @forwarderUuid = '27aa53ae-a5c0-4b1b-8051-389c65c98df2'
          record =
            name: 'Forwarder'
            uuid: @forwarderUuid
            meshblu:
              forwarders:
                sent: [ @hookOptions ]
          @devices.insert record, done

        beforeEach (done) ->
          uuid = @forwarderUuid
          type = 'sent'
          message =
            devices: ['*']
          @sut.forward {uuid, type, message}, (error) =>
            done error

        it 'should send a webhook', ->
          newMessage =
            devices: ['*']
            forwardedFor: [@forwarderUuid]

          expect(@MessageWebhook).to.have.been.calledWith uuid: @forwarderUuid, type: 'sent', options: @hookOptions
          expect(@messageWebhook.send).to.have.been.calledWith newMessage

    context 'received', ->
      context 'with a subscription', ->
        beforeEach (done) ->
          @forwarderUuid = 'eb76dac1-83d6-415b-a4e5-d4847d190ff8'
          record =
            name: 'Forwarder'
            uuid: @forwarderUuid
            configureWhitelist: [ @receiverUuid ]
          @devices.insert record, done

        beforeEach (done) ->
          record =
            emitterUuid: @forwarderUuid
            subscriberUuid: @receiverUuid
            type: 'received'
          @subscriptions.insert record, done

        beforeEach (done) ->
          uuid = @forwarderUuid
          type = 'received'
          message =
            devices: ['*']
          @sut.forward {uuid, type, message}, (error) =>
            done error

        it 'should forward a message', ->
          newMessage =
            devices: ['*']
            forwardedFor: [@forwarderUuid]

          expect(@publisher.publish).to.have.been.calledWith 'received', @receiverUuid, newMessage
