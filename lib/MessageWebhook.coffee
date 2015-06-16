_ = require 'lodash'

class MessageWebhook
  constructor: (@options, dependencies={}) ->
    @request = dependencies.request ? require 'request'

  send: (message, callback=->) =>
    options = _.extend {}, @options, json: message
    @request options, (error, response) =>
      return callback error if error?
      return callback new Error "HTTP Status: #{response.statusCode}" unless _.inRange response.statusCode, 200, 300
      callback()

module.exports = MessageWebhook
