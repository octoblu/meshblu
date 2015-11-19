_ = require 'lodash'
async = require 'async'
Publisher = require './Publisher'
SimpleAuth = require './simpleAuth'

PUBLISHER = new Publisher namespace: 'meshblu'

class PublishConfig
  constructor: ({@uuid,@config,@database,@forwardedFor}) ->
    @Device = require './models/device'
    @MessageWebhook = require './MessageWebhook'
    @forwardedFor ?= []
    @forwardedFor = _.union @forwardedFor, [@uuid]

  publish: (callback) =>
    async.series [@doPublish, @callWebhooks, @forwardPublishToDevices], callback

  # Private(ish) methods
  callWebhooks: (callback) =>
    @fetchDevice @uuid, (error, device) =>
      return callback() unless device? && device.meshblu?
      hooks = device.meshblu.configHooks ? []
      async.each hooks, @callWebhook, callback

  callWebhook: (hook, callback) =>
    device = new @Device {@uuid}, {@database}
    messageWebhook = new @MessageWebhook @uuid, hook, device: device
    messageWebhook.send @config, (error) =>
      callback() # if error, move on

  doPublish: (callback) =>
    PUBLISHER.publish 'config', @uuid, @config, callback

  fetchDevice: (uuid, callback) =>
    device = new @Device {uuid}, {@database}
    device.fetch (error, result) =>
      # ignore errors, because not finding the device means we won't forward to them
      callback null, result

  fetchToAndFromDevice: ({fromUuid, toUuid}, callback) =>
    async.parallel {
      fromDevice: async.apply @fetchDevice, fromUuid
      toDevice:   async.apply @fetchDevice, toUuid
    }, callback

  forwardPublish: ({uuid}, callback) =>
    toUuid   = uuid
    fromUuid = @uuid

    @shouldSend {fromUuid, toUuid}, (error, canSend) =>
      return callback error if error?
      return callback() unless canSend

      publishConfig = new PublishConfig
        uuid: toUuid
        config: @config
        database: @database
        forwardedFor: @forwardedFor
      publishConfig.publish callback

  forwardPublishToDevices: (callback) =>
    @fetchDevice @uuid, (error, device) =>
      return callback error if error?
      return callback null unless device? and device.meshblu?

      configForward = device.meshblu.configForward ? []
      async.eachSeries configForward, @forwardPublish, callback

  shouldSend: ({fromUuid, toUuid}, callback) =>
    return callback null, false if _.contains @forwardedFor, toUuid

    @fetchToAndFromDevice {fromUuid, toUuid}, (error, {fromDevice, toDevice}={}) =>
      return callback error if error?
      simpleAuth = new SimpleAuth
      simpleAuth.canSend fromDevice, toDevice, {}, callback

  module.exports = PublishConfig
