MessageWebhook = require '../../lib/MessageWebhook'

describe 'MessageWebhook', ->
  beforeEach ->
    @request = sinon.stub()
    @dependencies = request: @request

  describe '->send', ->
    describe 'when instantiated with a url', ->
      describe 'when request fails', ->
        beforeEach ->
          @request.yields new Error
          @sut = new MessageWebhook url: 'http://google.com', @dependencies
          @sut.send foo: 'bar', (@error) =>

        it 'should call request with whatever I want', ->
          expect(@request).to.have.been.calledWith url: 'http://google.com', json: {foo: 'bar'}

        it 'should get error', ->
          expect(@error).to.exist

      describe 'when request do not fails, but returns error that shouldnt happen', ->
        beforeEach ->
          @request.yields null, {statusCode: 103}, 'dont PUT that there'
          @sut = new MessageWebhook url: 'http://google.com', @dependencies
          @sut.send foo: 'bar', (@error) =>

        it 'should call request with whatever I want', ->
          expect(@request).to.have.been.calledWith url: 'http://google.com', json: {foo: 'bar'}

        it 'should get error', ->
          expect(@error).to.exist
          expect(@error.message).to.deep.equal 'HTTP Status: 103'

      describe 'when request do fails and it mah fault', ->
        beforeEach ->
          @request.yields null, {statusCode: 429}, 'chillax broham'
          @sut = new MessageWebhook url: 'http://google.com', @dependencies
          @sut.send foo: 'bar', (@error) =>

        it 'should call request with whatever I want', ->
          expect(@request).to.have.been.calledWith url: 'http://google.com', json: {foo: 'bar'}

        it 'should get error', ->
          expect(@error).to.exist
          expect(@error.message).to.deep.equal 'HTTP Status: 429'

      describe 'when request do fails and it yo fault', ->
        beforeEach ->
          @request.yields null, {statusCode: 506}, 'pay me mo moneys'
          @sut = new MessageWebhook url: 'http://google.com', @dependencies
          @sut.send foo: 'bar', (@error) =>

        it 'should call request with whatever I want', ->
          expect(@request).to.have.been.calledWith url: 'http://google.com', json: {foo: 'bar'}

        it 'should get error', ->
          expect(@error).to.exist
          expect(@error.message).to.deep.equal 'HTTP Status: 506'

      describe 'when request dont fails', ->
        beforeEach ->
          @request.yields null, statusCode: 200, 'nothing wrong'
          @hook = url: 'http://facebook.com'
          @sut = new MessageWebhook @hook, @dependencies
          @sut.send czar: 'foo', (@error) =>

        it 'should get not error', ->
          expect(@error).not.to.exist

        it 'should call request with whatever else I want', ->
          expect(@request).to.have.been.calledWith url: 'http://facebook.com', json: {czar: 'foo'}

        it 'should not mutate my webhook', ->
          expect(@hook).to.deep.equal url: 'http://facebook.com'
