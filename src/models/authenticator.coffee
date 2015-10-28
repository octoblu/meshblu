_ = require 'lodash'
uuid = require 'uuid'
async = require 'async'
JobManager = require 'meshblu-core-job-manager'

class AuthenticatorError extends Error
  name: 'AuthenticatorError'
  constructor: (@code, @status) ->
    @message = "#{@code}: #{@status}"

class Authenticator
  constructor: (options={}, dependencies={}) ->
    {client,@namespace,@timeoutSeconds} = options
    @namespace ?= 'meshblu'
    @client = _.bindAll client
    @timeoutSeconds ?= 30
    @timeoutSeconds = 1 if @timeoutSeconds < 1
    @jobManager = new JobManager
      namespace: @namespace
      client: @client
      timeoutSeconds: @timeoutSeconds

    {@uuid} = dependencies
    @uuid ?= uuid

  authenticate: (id, token, callback) ->
    responseId = @uuid.v1()

    metadata =
      auth:
        uuid:  id
        token: token
      jobType: 'authenticate'
      responseId: responseId

    options =
      responseId: responseId
      metadata: metadata

    @jobManager.createRequest options, (error) =>
      return callback error if error?

      @listenForResponse metadata.responseId, callback

  listenForResponse: (responseId, callback) =>
    @jobManager.getResponse responseId, (error, response) =>
      return callback error if error?
      return callback new Error('No response from authenticate worker') unless response?

      {metadata,rawData} = response
      data = JSON.parse rawData

      return callback new AuthenticatorError(metadata.code, metadata.status) if metadata.code > 299

      callback null, data.authenticated

module.exports = Authenticator
