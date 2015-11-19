async = require 'async'
http = require 'http'
PublishConfig = require '../../lib/publishConfig'
Subscriber = require '../../lib/Subscriber'
Database = require '../test-database'
clearCache = require '../../lib/clearCache'

describe 'PublishConfig', ->
  beforeEach (done) ->
    uuids = [
      'uuid-device-being-configged'
      'uuid-interested-device'
      'uuid-uninterested-device'
      'uuid-emitter'
      'uuid-middleman'
      'uuid-subscriber'
    ]
    async.each uuids, clearCache, done

  beforeEach (done) ->
    Database.open (error, @database) => done error

  beforeEach (done) ->
    @database.devices.insert
      uuid: 'uuid-device-being-configged'
      meshblu:
        configForward: [
          {uuid: 'uuid-interested-device'}
          {uuid: 'uuid-uninterested-device'}
        ]
    , done

  beforeEach ->
    @sut = new PublishConfig
      uuid: 'uuid-device-being-configged'
      config: {foo: 'bar'}
      database: @database

  describe 'when called', ->
    beforeEach (done)->
      subscriber = new Subscriber namespace: 'meshblu'
      subscriber.once 'message', (type, @message) =>

      subscriber.subscribe 'config', 'uuid-device-being-configged', =>
        @sut.publish done

    it "should publish the config to 'uuid-device-being-configged'", ->
      expect(@message).to.deep.equal foo: 'bar'

  describe "when another device is in the configForward list", ->
    beforeEach (done) ->
      @database.devices.insert
        uuid: 'uuid-interested-device'
        sendWhitelist: ['uuid-device-being-configged']
      , done

    beforeEach (done) ->
      subscriber = new Subscriber namespace: 'meshblu'
      subscriber.once 'message', (type, @config) =>
        done()

      subscriber.subscribe 'config', 'uuid-interested-device', =>
        @sut.publish()

    it "should publish its config to a device in to it", ->
      expect(@config).to.deep.equal foo: 'bar'

  describe "when forwarding a config to a device that doesn't want it", ->
    beforeEach (done) ->
      @database.devices.insert
        uuid: 'uuid-uninterested-device'
        sendWhitelist: []
      , done

    beforeEach (done) ->
      @configEvent = sinon.spy()
      subscriber = new Subscriber namespace: 'meshblu'
      subscriber.once 'message', @configEvent
      subscriber.subscribe 'config', 'uuid-uninterested-device', =>
        @sut.publish done

    it 'should not send a message to that device', ->
      expect(@configEvent).to.not.have.been.called

  describe "when forwarding the config to oneself", ->
    beforeEach (done) ->
      @database.devices.insert
        uuid: 'uuid-interested-device'
        sendWhitelist: ['uuid-device-being-configged', 'uuid-interested-device']
        meshblu:
          configForward: [
            uuid: 'uuid-interested-device'
          ]
      , done

    beforeEach (done) ->
      @configEvent = sinon.spy()
      @subscriber = new Subscriber namespace: 'meshblu'
      @subscriber.on 'message', @configEvent
      @subscriber.subscribe 'config', 'uuid-interested-device', =>
        @sut.publish done

    afterEach ->
      @subscriber.removeAllListeners()

    it 'should break free from the infinite loop and get here', ->
      expect(@configEvent).to.have.been.calledOnce

  describe "when another device is in the configForward list many times", ->
    beforeEach (done) ->
      query = {uuid: 'uuid-device-being-configged'}
      update = {$set: 'meshblu.configForward': [
        {uuid: 'uuid-interested-device'}
        {uuid: 'uuid-interested-device'}
        {uuid: 'uuid-interested-device'}
      ]}

      @database.devices.update query, update, done

    beforeEach (done) ->
      @database.devices.insert
        uuid: 'uuid-interested-device'
        sendWhitelist: ['uuid-device-being-configged']
      , done

    beforeEach (done) ->
      @subscriber = new Subscriber namespace: 'meshblu'
      @subscriber.on 'message', @onMessage = sinon.spy()

      @subscriber.subscribe 'config', 'uuid-interested-device', =>
        @sut.publish done

    afterEach ->
      @subscriber.removeAllListeners()

    it "should publish its 3 times", ->
      expect(@onMessage).to.have.been.calledThrice

  describe 'when emitter forwards config through a middleman to subscriber', ->
    beforeEach (done) ->
      emitter =
        uuid: 'uuid-emitter'
        meshblu:
          configForward: [{uuid: 'uuid-middleman'}]

      @database.devices.insert emitter, done

    beforeEach (done) ->
      middleman =
        uuid: 'uuid-middleman'
        sendWhitelist: ['uuid-emitter']
        meshblu:
          configForward: [{uuid: 'uuid-subscriber'}]

      @database.devices.insert middleman, done

    beforeEach (done) ->
      subscriber =
        uuid: 'uuid-subscriber'
        sendWhitelist: ['uuid-middleman']

      @database.devices.insert subscriber, done

    describe 'when the emitter emits a config', ->
      beforeEach (done) ->
        @sut = new PublishConfig
          uuid: 'uuid-emitter'
          config: {foo: 'bar'}
          database: @database

        subscriber = new Subscriber namespace: 'meshblu'
        subscriber.once 'message', @onMessage = sinon.spy()
        subscriber.subscribe 'config', 'uuid-subscriber', =>
          @sut.publish done

      it 'should call onMessage', ->
        expect(@onMessage).to.have.been.calledOnce

  describe 'when emitter forwards config through a middleman to a webhook', ->
    beforeEach (done) ->
      emitter =
        uuid: 'uuid-emitter'
        meshblu:
          configForward: [{uuid: 'uuid-middleman'}]

      @database.devices.insert emitter, done

    beforeEach (done) ->
      middleman =
        uuid: 'uuid-middleman'
        sendWhitelist: ['uuid-emitter']
        meshblu:
          configHooks: [{url: "http://localhost:38234", method: 'POST'}]

      @database.devices.insert middleman, done

    beforeEach (done) ->
      @onRequest = sinon.spy (req,res) =>
        res.writeHead(204)
        res.end()
      @server = http.createServer @onRequest
      @server.listen 38234, done

    afterEach (done) ->
      @server.close done

    describe 'when the emitter emits a config', ->
      beforeEach (done) ->
        @sut = new PublishConfig
          uuid: 'uuid-emitter'
          config: {foo: 'bar'}
          database: @database

        @sut.publish (error) =>
          return done error if error?
          setTimeout done, 100

      it 'should call onRequest', ->
        expect(@onRequest).to.have.been.calledOnce

  describe 'when emitter forwards config through a middleman to a webhook that isnt listening', ->
    beforeEach (done) ->
      emitter =
        uuid: 'uuid-emitter'
        meshblu:
          configForward: [{uuid: 'uuid-middleman'}]

      @database.devices.insert emitter, done

    beforeEach (done) ->
      middleman =
        uuid: 'uuid-middleman'
        sendWhitelist: ['uuid-emitter']
        meshblu:
          configHooks: [{url: "http://localhost:38234", method: 'POST'}]

      @database.devices.insert middleman, done

    describe 'when the emitter emits a config', ->
      beforeEach (done) ->
        @sut = new PublishConfig
          uuid: 'uuid-emitter'
          config: {foo: 'bar'}
          database: @database

        @sut.publish done

      it 'should get here within the timeout', ->
        expect(true)
