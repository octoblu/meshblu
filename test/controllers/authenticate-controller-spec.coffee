{EventEmitter} = require 'events'
httpMocks      = require 'node-mocks-http'
AuthenticateController = require '../../src/controllers/authenticate-controller'

describe 'AuthenticateController', ->
  describe 'authenticate', ->
    beforeEach ->
      @authenticator = authenticate: sinon.stub()
      @sut = new AuthenticateController {}, authenticator: @authenticator

    describe 'when authenticator.authenticate yields true for a specific device', ->
      beforeEach ->
        @authenticator.authenticate.withArgs('uuid', 'token').yields null, true

      describe 'when called with a request containing no auth information', ->
        beforeEach (done) ->
          @request  = httpMocks.createRequest()
          @response = httpMocks.createResponse eventEmitter: EventEmitter
          @response.on 'end', done

          @sut.authenticate @request, @response

        it 'should respond with a 401', ->
          expect(@response.statusCode).to.equal 401

      describe 'when called with a request containing correct auth information', ->
        beforeEach (done) ->
          basicAuth = new Buffer("uuid:token").toString 'base64'
          @request  = httpMocks.createRequest headers: authorization: "Basic #{basicAuth}"
          @response = httpMocks.createResponse eventEmitter: EventEmitter
          @response.on 'end', done

          @sut.authenticate @request, @response

        it 'should respond with a 204', ->
          expect(@response.statusCode).to.equal 204

    describe 'when authenticator.authenticate yields false for a specific device', ->
      beforeEach ->
        @authenticator.authenticate.withArgs('wrong', 'person').yields null, false

      describe 'when called with a request containing incorrect auth information', ->
        beforeEach (done) ->
          basicAuth = new Buffer("wrong:person").toString 'base64'
          @request  = httpMocks.createRequest headers: authorization: "Basic #{basicAuth}"
          @response = httpMocks.createResponse eventEmitter: EventEmitter
          @response.on 'end', done

          @sut.authenticate @request, @response

        it 'should respond with a 403', ->
          expect(@response.statusCode).to.equal 403

    describe 'when authenticator.authenticate yields an error', ->
      beforeEach ->
        @authenticator.authenticate.withArgs('fatal', 'error').yields new Error("oh no!")

      describe 'when called with a request containing auth information', ->
        beforeEach (done) ->
          basicAuth = new Buffer("fatal:error").toString 'base64'
          @request  = httpMocks.createRequest headers: authorization: "Basic #{basicAuth}"
          @response = httpMocks.createResponse eventEmitter: EventEmitter
          @response.on 'end', done

          @sut.authenticate @request, @response

        it 'should respond with a 502', ->
          expect(@response.statusCode).to.equal 502
