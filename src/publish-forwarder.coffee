_ = require 'lodash'
async = require 'async'
debug = require('debug')('meshblu:publish-forwarder')

class PublishForwarder
  constructor: ({@publisher}, dependencies={}) ->
    {@devices,@subscriptions,@MessageWebhook,@Device} = dependencies
    @SubscriptionGetter = require '../lib/SubscriptionGetter'
    @Device         ?= require '../lib/models/device'
    @MessageWebhook ?= require '../lib/MessageWebhook'

  forward: ({type, uuid, message}, callback) =>
    message ?= {}
    message = _.clone message
    message.forwardedFor ?= []
    device = new @Device {uuid}, {database: {@devices}}
    device.fetch (error, attributes) =>
      return callback error if error?

      {uuid} = attributes

      if _.contains message.forwardedFor, uuid
        debug 'Refusing to forward message to a device already in forwardedFor', uuid
        error = new Error 'Device already in forwardedFor'
        error.code = 508
        return callback error

      # use the real uuid of the device
      message.forwardedFor.push uuid

      async.parallel [
        async.apply @_handleSubsriptions, {uuid, type, message, device}
        async.apply @_handleForwarders, {uuid, type, message, device}
      ], callback

  _webhook: ({type, options, message, device}, callback) =>
    messageWebhook = new @MessageWebhook {uuid: device.uuid, type, options}, {device: device}
    messageWebhook.send message, (error) =>
      callback() # if error, move on

  _handleSubsriptions: ({type, uuid, message}, callback) =>
    subscriptionGetter = new @SubscriptionGetter {emitterUuid: uuid, type: type}, {@devices, @subscriptions}
    subscriptionGetter.get (error, toUuids) =>
      return callback error if error?
      return callback null unless _.isArray toUuids

      async.each toUuids, (toUuid, next) =>
        @publisher.publish type, toUuid, message, next
      , callback

  _handleForwarders: ({type, uuid, message, device}, callback) =>
    device.fetch (error, attributes) =>
      return callback error if error?

      forwarders = attributes.meshblu?.forwarders?[type] || []
      async.each forwarders, (forwarder, next) =>
        return next() unless forwarder.type == 'webhook'
        @_webhook {type, options: forwarder, message, device}, next
      , callback

module.exports = PublishForwarder
