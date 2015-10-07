_                = require 'lodash'
LogElasticSearch = null

describe 'logElasticSearch', ->
  beforeEach ->
    LogElasticSearch = require '../../lib/logElasticSearch'

  describe '->constructor', ->
    describe 'when we pass in ElasticSearch', ->
      beforeEach ->
        @spy = sinon.stub()
        @console = {}
        @options = marty: 'mcfly'
        @sut = new LogElasticSearch @options, console: @console, ElasticSearch: @spy

      it 'should instantiate an ElasticSearch with the options', ->
        expect(@spy).to.have.been.calledWith @options

      it 'should assign the result to @elasticsearch', ->
        expect(@sut.elasticsearch).to.be.an.instanceOf @spy

  describe '->log', ->
    beforeEach ->
      @logError = sinon.spy()
      @sut = new LogElasticSearch {}, logError: @logError, ElasticSearch: ->
      @elasticsearch = @sut.elasticsearch
      @elasticsearch.create = sinon.stub()

    describe 'when called an eventcode of 201 and some data', ->
      beforeEach ->
        @sut.log 201, {hello: 'mcfly'}

      it 'should call create with the data in the body', ->
        expect(@elasticsearch.create).to.have.been.calledWith index: "meshblu_events_201", body: {hello: 'mcfly'}, type: 'event'

    describe 'when called an eventcode of 555 and some data', ->
      beforeEach ->
        @sut.log 555, {great: 'scott!'}

      it 'should call create with the data in the body', ->
        expect(@elasticsearch.create).to.have.been.calledWith index: "meshblu_events_555", body: {great: 'scott!'}, type: 'event'

    describe 'when elasticsearch.create yields an error', ->
      beforeEach ->
        @error = new Error("don't go on the water, unless you have power")
        @elasticsearch.create.yields @error
        @sut.log()

      it 'should @logError the error', ->
        expect(@logError).to.have.been.calledWith @error

    describe 'when elasticsearch.create yields no error', ->
      beforeEach ->
        @elasticsearch.create.yields null
        @sut.log()

      it 'should not @logError anything', ->
        expect(@logError).not.to.have.been.called
