_ = require 'lodash'
async = require 'async'

module.exports = (device, hooks, message, callback=_.noop, dependencies={}) ->
  MessageWebhook = dependencies.MessageWebhook ? require './MessageWebhook'
  hooks ?= []

  async.map hooks, (hook, cb=->) =>
    options =
      uuid: device.uuid
      options: hook

    messageWebhook = new MessageWebhook options
    messageWebhook.send message, (error) =>
      cb null, error
  , (error, errors) =>
    callback errors
