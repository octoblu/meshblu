_ = require 'lodash'
config = require '../config'
Device = require './models/device'

class MessageWebhook
  @HTTP_SIGNATURE_OPTIONS:
    keyId: 'meshblu-webhook-key'
    key: config.privateKey
    headers: [ 'date', 'X-MESHBLU-UUID']

  constructor: (@uuid, @options, dependencies={}) ->
    @request = dependencies.request ? require 'request'
    @device = dependencies.device
    @device ?= new Device uuid: @uuid

  generateAndForwardMeshbluCredentials: (callback=->) =>
    @device.generateAndStoreTokenInCache callback

  send: (message, callback=->) =>
    if @options.signRequest && config.privateKey?
      options =
        headers:
          'X-MESHBLU-UUID': @uuid
        httpSignature: MessageWebhook.HTTP_SIGNATURE_OPTIONS
      @doRequest options, message, callback
      return

    if @options.generateAndForwardMeshbluCredentials
      @generateAndForwardMeshbluCredentials (error, token) =>
        bearer = new Buffer("#{@uuid}:#{token}").toString('base64')
        @doRequest auth: bearer: bearer, message, (error) =>
          @removeToken(token)
          callback error

      return

    @doRequest {}, message, callback

  doRequest: (options, message={}, callback) =>
    deviceOptions = _.omit @options, 'generateAndForwardMeshbluCredentials', 'signRequest'
    options = _.defaults json: message, deviceOptions, options
    @request options, (error, response) =>
      return callback error if error?
      return callback new Error "HTTP Status: #{response.statusCode}" unless _.inRange response.statusCode, 200, 300
      callback()

  removeToken: (token) =>
    @device.removeTokenFromCache token, (error) =>

module.exports = MessageWebhook
