MessageWebhook = require '../../lib/MessageWebhook'

describe 'MessageWebhook', ->
  beforeEach ->
    @deviceRecord = {}
    @device =
      generateToken: sinon.stub()
      removeTokenFromCache: sinon.stub()
      generateAndStoreTokenInCache: sinon.stub()
    @request               = sinon.stub()
    @generateAndStoreToken = sinon.stub()
    @revokeToken           = sinon.stub()
    @dependencies = {@request, @generateAndStoreToken, @revokeToken, @device}

  describe '->send', ->
    describe 'when instantiated with a url', ->
      beforeEach ->
        options =
          uuid: @deviceRecord.uuid
          options: url: 'http://google.com'
          type: 'received'

        @sut = new MessageWebhook options, @dependencies

      describe 'when request fails', ->
        beforeEach ->
          @request.yields new Error
          @sut.send foo: 'bar', (@error) =>

        it 'should call request with whatever I want', ->
          expect(@request).to.have.been.calledWith
            url: 'http://google.com'
            headers:
              'X-MESHBLU-MESSAGE-TYPE': 'received'
            json: {foo: 'bar'}

        it 'should get error', ->
          expect(@error).to.exist

      describe 'when request do not fails, but returns error that shouldnt happen', ->
        beforeEach ->
          @request.yields null, {statusCode: 103}, 'dont PUT that there'
          @sut.send foo: 'bar', (@error) =>

        it 'should call request with whatever I want', ->
          expect(@request).to.have.been.calledWith
            url: 'http://google.com'
            json: {foo: 'bar'}
            headers:
              'X-MESHBLU-MESSAGE-TYPE': 'received'

        it 'should get error', ->
          expect(@error).to.exist
          expect(@error.message).to.deep.equal 'HTTP Status: 103'

      describe 'when request do fails and it mah fault', ->
        beforeEach ->
          @request.yields null, {statusCode: 429}, 'chillax broham'
          @sut.send foo: 'bar', (@error) =>

        it 'should call request with whatever I want', ->
          expect(@request).to.have.been.calledWith
            url: 'http://google.com'
            json: {foo: 'bar'}
            headers:
              'X-MESHBLU-MESSAGE-TYPE': 'received'

        it 'should get error', ->
          expect(@error).to.exist
          expect(@error.message).to.deep.equal 'HTTP Status: 429'

      describe 'when request do fails and it yo fault', ->
        beforeEach ->
          @request.yields null, {statusCode: 506}, 'pay me mo moneys'
          @sut.send foo: 'bar', (@error) =>

        it 'should call request with whatever I want', ->
          expect(@request).to.have.been.calledWith
            url: 'http://google.com'
            json: {foo: 'bar'}
            headers:
              'X-MESHBLU-MESSAGE-TYPE': 'received'

        it 'should get error', ->
          expect(@error).to.exist
          expect(@error.message).to.deep.equal 'HTTP Status: 506'

      describe 'when request dont fails', ->
        beforeEach ->
          @request.yields null, statusCode: 200, 'nothing wrong'
          @hook = url: 'http://facebook.com'
          options =
            uuid: @deviceRecord.uuid
            options: @hook
            type: 'received'
          @sut = new MessageWebhook options, @dependencies
          @sut.send czar: 'foo', (@error) =>

        it 'should get not error', ->
          expect(@error).not.to.exist

        it 'should call request with whatever else I want', ->
          expect(@request).to.have.been.calledWith
            url: 'http://facebook.com'
            json: {czar: 'foo'}
            headers:
              'X-MESHBLU-MESSAGE-TYPE': 'received'

        it 'should not mutate my webhook', ->
          expect(@hook).to.deep.equal url: 'http://facebook.com'

      describe 'when using a crazy scheme to get meshblu credentials forwarded', ->
        beforeEach ->
          @request.yields null, statusCode: 200, 'nothing wrong'
          @hook = url: 'http://facebook.com', generateAndForwardMeshbluCredentials: true
          @deviceRecord = uuid: 'test'
          options =
            uuid: @deviceRecord.uuid
            options: @hook
            type: 'received'
          @sut = new MessageWebhook options, @dependencies
          @sut.generateAndForwardMeshbluCredentials = sinon.stub().yields null, 'gobbledegook'
          @sut.send czar: 'foo', (@error) =>

        it 'should get not error', ->
          expect(@error).not.to.exist

        it 'should call request and add my auth', ->
          expect(@request).to.have.been.calledWith
            url: 'http://facebook.com'
            auth: {bearer: 'dGVzdDpnb2JibGVkZWdvb2s='}
            json: {czar: 'foo'}
            headers:
              'X-MESHBLU-MESSAGE-TYPE': 'received'

      describe 'when using a crazy scheme to get meshblu credentials forwarded but I already put in my own auth', ->
        beforeEach ->
          @request.yields null, statusCode: 200, 'nothing wrong'
          @hook = url: 'http://facebook.com', generateAndForwardMeshbluCredentials: true, auth: 'basic'
          options =
            uuid: @deviceRecord.uuid
            options: @hook
            type: 'received'
          @sut = new MessageWebhook options, @dependencies
          @sut.generateAndForwardMeshbluCredentials = sinon.stub().yields null
          @sut.send czar: 'foo', (@error) =>

        it 'should get not error', ->
          expect(@error).not.to.exist

        it 'should call generateAndForwardMeshbluCredentials', ->
          expect(@sut.generateAndForwardMeshbluCredentials).to.have.been.called

        it 'should not override my auth', ->
          expect(@request).to.have.been.calledWith
            url: 'http://facebook.com'
            auth: 'basic'
            json: {czar: 'foo'}
            headers:
              'X-MESHBLU-MESSAGE-TYPE': 'received'

  describe '->generateAndForwardMeshbluCredentials', ->
    describe 'when using a crazy scheme to get meshblu credentials forwarded', ->
      beforeEach ->
        @request.yields null, statusCode: 200, 'nothing wrong'
        @hook = url: 'http://facebook.com', generateAndForwardMeshbluCredentials: true
        @deviceRecord = uuid: 'test'
        options =
          uuid: @deviceRecord.uuid
          options: @hook
          type: 'received'
        @device.generateAndStoreTokenInCache.yields null, 'gobbledegook'
        @sut = new MessageWebhook options, @dependencies
        @sut.generateAndForwardMeshbluCredentials (@error, @token) =>

      it 'should get not error', ->
        expect(@error).not.to.exist

      it 'should yield a token', ->
        expect(@token).to.deep.equal 'gobbledegook'

  describe '->removeToken', ->
    describe 'when using a crazy scheme to get meshblu credentials forwarded', ->
      beforeEach ->
        @hook = url: 'http://facebook.com', generateAndForwardMeshbluCredentials: true
        @deviceRecord = uuid: 'test'
        options =
          uuid: @deviceRecord.uuid
          options: @hook
          type: 'received'
        @sut = new MessageWebhook options, @dependencies
        @revokeToken.yields null
        @sut.removeToken 'test', (@error) =>

      it 'should get not error', ->
        expect(@error).not.to.exist

      it 'should call removeTokenFromCache', ->
        expect(@device.removeTokenFromCache).to.have.been.calledWith 'test'
