async = require 'async'
Publisher = require './Publisher'
SimpleAuth = require './SimpleAuth'

Device = null

class PublishConfig
  constructor: ({@uuid,@config,@database}) ->
    Device = require './models/device'

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

    @fetchDevice @uuid, (error, fromDevice) =>
      return callback error if error?
      @fetchDevice toUuid, (error, toDevice) =>
        return callback error if error?
        simpleAuth = new SimpleAuth
        simpleAuth.canSend fromDevice, toDevice, {}, (error, canSend)=>
          return callback error if error?
          return callback() unless canSend

          publishConfig = new PublishConfig uuid: toUuid, config: @config, database: @database
          publishConfig.publish callback

  module.exports = PublishConfig
