Authenticator = require '../../src/models/authenticator'
JobManager = require 'meshblu-core-job-manager'
async = require 'async'
redis = require 'fakeredis'
_ = require 'lodash'
uuid = require 'uuid'

describe 'Authenticator', ->
  beforeEach ->
    @redis = redis.createClient uuid.v1()
    @redis = _.bindAll @redis

  beforeEach ->
    @uuid = v1: sinon.stub()
    @sut = new Authenticator {namespace: 'test', timeoutSeconds: 1, client: @redis}, uuid: @uuid
    @jobManager = new JobManager namespace: 'test', client: @redis

  describe '->authenticate', ->
    describe 'when redis replies with true', ->
      beforeEach (done) ->
        @uuid.v1.returns 'some-uuid'

        metadata =
          code: 200

        data =
          authenticated: true

        @jobManager.createResponse responseId: 'some-uuid', metadata: metadata, data: data, done

      beforeEach (done) ->
        @sut.authenticate 'uuid', 'token', (@error, @isAuthenticated) => done()

      it 'should no error', ->
        expect(@error).not.to.exist

      it 'should yield true', ->
        expect(@isAuthenticated).to.be.true

      it 'should have added a request reference to the request queue', (done) ->
        @redis.lindex 'test:request:queue', 0, (error, result) =>
          return done error if error?

          expect(result).to.deep.equal 'test:some-uuid'
          done()

      it 'should have added a request metadata to the request hash set', (done) ->
        @redis.hget 'test:some-uuid', 'request:metadata', (error, metadataStr) =>
          return done error if error?

          metadata = JSON.parse metadataStr

          expect(metadata).to.deep.equal
            auth:
              uuid: "uuid"
              token: "token"
            responseId: "some-uuid"
            jobType: "authenticate"

          done()

    describe 'when the auth worker replies with false', ->
      beforeEach (done) ->
        @uuid.v1.returns 'some-other-uuid'

        metadata =
          code: 200

        data =
          authenticated: false

        @jobManager.createResponse responseId: 'some-other-uuid', metadata: metadata, data: data, done

      beforeEach (done) ->
        @sut.authenticate 'uuid', 'token', (@error, @isAuthenticated) => done()

      it 'should no error', ->
        expect(@error).not.to.exist

      it 'should yield false', ->
        expect(@isAuthenticated).to.be.false

      it 'should have added a job to the request queue', (done) ->
        @redis.lindex 'test:request:queue', 0, (error, requestKey) =>
          return done error if error?
          expect(requestKey).to.deep.equal 'test:some-other-uuid'
          done()

      it 'should have added a request metadata to the request hash set', (done) ->
        @redis.hget 'test:some-other-uuid', 'request:metadata', (error, metadataStr) =>
          return done error if error?

          metadata = JSON.parse metadataStr

          expect(metadata).to.deep.equal
            auth:
              uuid: "uuid"
              token: "token"
            responseId: "some-other-uuid"
            jobType: "authenticate"

          done()

    describe 'when the auth worker replies with an error', ->
      beforeEach (done) ->
        @uuid.v1.returns 'some-uuid'

        metadata =
          code: 500
          status: 'uh oh'

        @jobManager.createResponse responseId: 'some-uuid', metadata: metadata, done

      beforeEach (done) ->
        @sut.authenticate 'uuid', 'token', (@error, @isAuthenticated) => done()

      it 'should error', ->
        expect(@error.code).to.equal 500
        expect(@error.status).to.equal 'uh oh'
        expect(=> throw @error).to.throw '500: uh oh'

    describe 'when the auth worker never replies', ->
      beforeEach (done) ->
        @timeout 3000
        @sut.authenticate 'uuid', 'token', (@error, @isAuthenticated) => done()

      it 'should error', ->
        expect(@isAuthenticated).not.to.exist
        expect(=> throw @error).to.throw 'No response from authenticate worker'
