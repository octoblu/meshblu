_ = require 'lodash'
Device = require './models/device'

class MessageWebhook
  constructor: (@uuid, @options, dependencies={}) ->
    @request = dependencies.request ? require 'request'
    @device = dependencies.device
    @device ?= new Device uuid: @uuid

  generateAndForwardMeshbluCredentials: (callback=->) =>
    return callback() unless @options.generateAndForwardMeshbluCredentials
    @device.generateAndStoreTokenInCache (error, token) =>
      return callback error if error?
      callback null, token

  send: (message, callback=->) =>
    @generateAndForwardMeshbluCredentials (error, token) =>
      options = _.extend {}, _.omit(@options, 'generateAndForwardMeshbluCredentials'), json: message
      options.auth ?= bearer: new Buffer("#{@uuid}:#{token}").toString('base64') if token
      @request options, (error, response) =>
        @removeToken(token) if token?
        return callback error if error?
        return callback new Error "HTTP Status: #{response.statusCode}" unless _.inRange response.statusCode, 200, 300
        callback()

  removeToken: (token) =>
    @device.removeTokenFromCache token, (error) =>

module.exports = MessageWebhook
