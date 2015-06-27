_ = require 'lodash'

class MessageWebhook
  constructor: (@device, @options, dependencies={}) ->
    @request = dependencies.request ? require 'request'
    @generateAndStoreToken = dependencies.generateAndStoreToken ? require './generateAndStoreToken'
    @revokeToken = dependencies.revokeToken ? require './revokeToken'

  generateAndForwardMeshbluCredentials: (callback=->) =>
    return callback() unless @options.generateAndForwardMeshbluCredentials
    @generateAndStoreToken @device, @device.uuid, (error, data) =>
      return callback error if error?
      callback null, data.token

  send: (message, callback=->) =>
    @generateAndForwardMeshbluCredentials (error, token) =>
      options = _.extend {}, _.omit(@options, 'generateAndForwardMeshbluCredentials'), json: message
      options.auth ?= bearer: new Buffer("#{@device.uuid}:#{token}").toString('base64') if token
      @request options, (error, response) =>
        @removeToken(token) if token?
        return callback error if error?
        return callback new Error "HTTP Status: #{response.statusCode}" unless _.inRange response.statusCode, 200, 300
        callback()

  removeToken: (token) =>
    @revokeToken @device, @device.uuid, token, (error) =>

module.exports = MessageWebhook
