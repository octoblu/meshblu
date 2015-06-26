_ = require 'lodash'
async = require 'async'
messageIOEmitter = require('./createMessageIOEmitter')()
debug = require('debug')('meshblu:doMessageForward')

module.exports = (forwarders=[], message, fromUuid, callback=_.noop, dependencies={}) ->
  debug 'forward to', forwarders
  async.map forwarders, (forwarder, cb=->) =>
    message.meshblu ?= {}
    message.meshblu.forwardedFor ?= []

    if _.contains message.meshblu.forwardedFor, fromUuid
      debug 'Refusing to forward message to a device already in forwardedFor', fromUuid
      return cb()

    message.meshblu.forwardedFor.push fromUuid
    message.devices = [forwarder]
    message.fromUuid = fromUuid
    cb null, forwardTo: forwarder, message: message
  , (error, messages) =>
    callback error, _.compact(messages)
