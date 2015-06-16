_ = require 'lodash'
async = require 'async'

module.exports = (hooks, message, callback=_.noop, dependencies={}) ->
  MessageWebhook = dependencies.MessageWebhook ? require './MessageWebhook'
  hooks ?= []
  
  async.map hooks, (hook, cb=->) =>
    messageWebhook = new MessageWebhook hook
    messageWebhook.send message, (error) =>
      cb null, error
  , (error, errors) =>
    callback errors
