_ = require 'lodash'
async = require 'async'
debug = require('debug')('meshblu:doMessageForward')

module.exports = (forwarders=[], message, fromUuid, callback=_.noop, dependencies={}) ->
  debug 'doMessageForward', forwarders, message
  async.map forwarders, (forwarder, cb=->) =>
    message ?= {}
    message.forwardedFor ?= []

    if _.contains message.forwardedFor, fromUuid
      debug 'Refusing to forward message to a device already in forwardedFor', fromUuid
      return cb()

    message.forwardedFor.push fromUuid
    message.devices = [forwarder]
    message.fromUuid = fromUuid
    cb null, forwardTo: forwarder, message: message
  , (error, messages) =>
    callback error, _.compact(messages)
