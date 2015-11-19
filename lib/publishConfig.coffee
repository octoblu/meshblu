_ = require 'lodash'
async = require 'async'
Publisher = require './Publisher'
SimpleAuth = require './SimpleAuth'

Device = null #circular dependencies are awesome.

class PublishConfig
  constructor: ({@uuid,@config,@database,@forwardedFor}) ->
    Device = require './models/device'
    @forwardedFor ?= []
    @forwardedFor = _.union @forwardedFor, [@uuid]

  publish: (callback) =>
    publisher = new Publisher namespace: 'meshblu'
    publisher.publish 'config', @uuid, @config, (error) =>
      return callback error if error?
      @fetchDevice @uuid, (error, device) =>
        return callback error if error?
        configForward = device?.meshblu?.configForward ? []
        async.eachSeries configForward, @forwardPublish, callback

  # Private(ish) methods
  # canSend: ({fromDevice, toDevice}, callback) =>

  fetchDevice: (uuid, callback) =>
    device = new Device {uuid}, {@database}
    device.fetch (error, result) =>
      callback null, result # ignore errors, cause why not?

  fetchToAndFromDevice: ({fromUuid, toUuid}, callback) =>
    async.parallel {
      fromDevice: async.apply @fetchDevice, fromUuid
      toDevice:   async.apply @fetchDevice, toUuid
    }, callback

  forwardPublish: ({uuid}, callback) =>
    toUuid = uuid
    fromUuid = @uuid
    return callback() if _.contains @forwardedFor, toUuid

    @fetchToAndFromDevice {fromUuid, toUuid}, (error, {fromDevice, toDevice}={}) =>
      simpleAuth = new SimpleAuth
      simpleAuth.canSend fromDevice, toDevice, {}, (error, canSend)=>
        return callback error if error?
        return callback() unless canSend

        publishConfig = new PublishConfig
          uuid: toUuid
          config: @config
          database: @database
          forwardedFor: @forwardedFor
        publishConfig.publish callback

  module.exports = PublishConfig
