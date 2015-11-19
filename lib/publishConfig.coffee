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

  fetchDevice: (uuid, callback) =>
    device = new Device {uuid: uuid}, database: @database
    device.fetch (error, result) =>
      callback null, result # ignore errors, cause why not?

  forwardPublish: ({uuid}, callback) =>
    toUuid = uuid
    return callback() if _.contains @forwardedFor, toUuid

    @fetchToAndFromDevice @uuid, toUuid, (error, fromDevice, toDevice) =>
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

  fetchToAndFromDevice: (fromUuid, toUuid, callback) =>
    @fetchDevice fromUuid, (error, fromDevice) =>
      return callback error if error?

      @fetchDevice toUuid, (error, toDevice) =>
        return callback error if error?
        callback null, fromDevice, toDevice


  module.exports = PublishConfig
