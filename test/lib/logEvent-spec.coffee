_            = require 'lodash'

describe 'logEvent', ->
  beforeEach =>
    @sut = require '../../lib/logEvent'
    @fakeMoment = {toISOString : sinon.stub()}

    @mockMoment = =>
      @fakeMoment
    @fakeTimestamp = 'I am an ISO String'
    @fakeMoment.toISOString.returns @fakeTimestamp
    @dependencies = config: {eventLoggers: {}}, moment: @mockMoment

  it 'should be a function', =>
    expect(@sut).to.be.a 'function'


  describe 'when file logging enabled', =>
    beforeEach =>
      @fakeFileLogger = log: sinon.stub()
      @dependencies.config.eventLoggers = file : @fakeFileLogger

    describe 'when eventCode is defined', =>
      beforeEach =>
        @eventCode = 201
        @data = something: 'here'
        @sut @eventCode, @data, @dependencies

      it 'should call toISOString on fakeMoment', =>
        expect(@fakeMoment.toISOString).to.have.been.called

      it 'should log with timestamp and eventCode', =>
        dataWithAdditions = _.extend {}, @data, timestamp: @fakeTimestamp, eventCode: @eventCode
        expect(@fakeFileLogger.log).to.have.been.calledWith 'info', dataWithAdditions

      it 'should not mutate data', =>
        expect(@data.timestamp).to.be.undefined

    describe 'when eventCode and data is undefined', =>
      beforeEach =>
        @eventCode = undefined
        @sut @eventCode, undefined, @dependencies

      it 'should set eventCode to 0', =>
        expect(@fakeFileLogger.log).to.have.been.calledWith 'info', {timestamp: @fakeTimestamp, eventCode: 0}

  describe 'when elasticSearch logging enabled', =>
    beforeEach =>
      @fakeElasticSearchLogger = log: sinon.stub()
      @dependencies.config.eventLoggers = elasticSearch : @fakeElasticSearchLogger

    describe 'when payload is not an object', =>
      beforeEach =>
        @data = something: 'here', uuid: 'd0269f1f-214f-4a2f-9e79-bc248f229ec1', payload: '1234'
        @sut 333, @data, @dependencies

      it 'should wrap payload', =>
        dataWithAdditions = _.extend {}, @data, timestamp: @fakeTimestamp, payload: {message: '1234'}
        expect(@fakeElasticSearchLogger.log).to.have.been.calledWith 333, dataWithAdditions

    describe 'when eventCode is defined', =>
      beforeEach =>
        @data = something: 'here', uuid: 'd0269f1f-214f-4a2f-9e79-bc248f229ec1'
        @sut 201, @data, @dependencies

      it 'should log with the eventCode and the data with timestamp mixed in', =>
        dataWithAdditions = _.extend {}, @data, timestamp: @fakeTimestamp
        expect(@fakeElasticSearchLogger.log).to.have.been.calledWith 201, dataWithAdditions


  describe 'when splunk logging enabled', =>
    beforeEach =>
      @fakeSplunkLogger = log: sinon.stub()
      @dependencies.config.eventLoggers = splunk : @fakeSplunkLogger

    describe 'when eventCode is defined', =>
      beforeEach =>
        @eventCode = 201
        @data = something: 'here', uuid: 'd0269f1f-214f-4a2f-9e79-bc248f229ec1'
        @sut @eventCode, @data, @dependencies

      it 'should log with the uuid as the type, adding timestamp and eventCode', =>
        dataWithAdditions = _.extend {}, @data, timestamp: @fakeTimestamp, eventCode: @eventCode
        expect(@fakeSplunkLogger.log).to.have.been.calledWith 'info', dataWithAdditions

  describe 'when console logging enabled', =>
    beforeEach =>
      @fakeConsoleLogger = log: sinon.stub()
      @dependencies.config.eventLoggers = console : @fakeConsoleLogger

    describe 'when eventCode is defined', =>
      beforeEach =>
        @eventCode = 201
        @data = something: 'here', uuid: 'd0269f1f-214f-4a2f-9e79-bc248f229ec1'
        @sut @eventCode, @data, @dependencies

      it 'should log with the uuid as the type, adding timestamp and eventCode', =>
        dataWithAdditions = _.extend {}, @data, timestamp: @fakeTimestamp, eventCode: @eventCode
        expect(@fakeConsoleLogger.log).to.have.been.calledWith 'info', dataWithAdditions