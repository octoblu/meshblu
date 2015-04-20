util = require "./util"
bcrypt = require "bcrypt"
_ = require "lodash"
authDevice = require "./authDevice"

class SimpleAuth
  asyncCallback : (error, result, callback) =>
    _.defer( => callback(error, result))

  checkLists: (fromDevice, toDevice, whitelist, blacklist, openByDefault) =>
    return false if !fromDevice || !toDevice

    return true if toDevice.uuid == fromDevice.uuid

    return true if _.contains whitelist, '*'

    return  _.contains(whitelist, fromDevice.uuid) if whitelist?

    return !_.contains(blacklist, fromDevice.uuid) if blacklist?

    openByDefault

  canDiscover: (fromDevice, toDevice, callback) =>
    process.exit(-1) unless callback?
    result = @checkLists fromDevice, toDevice, toDevice?.discoverWhitelist, toDevice?.discoverBlacklist, true
    @asyncCallback(null, result, callback)

  canReceive: (fromDevice, toDevice, callback) =>
    process.exit(-1) unless callback?
    result = @checkLists fromDevice, toDevice, toDevice?.receiveWhitelist, toDevice?.receiveBlacklist, true
    @asyncCallback(null, result, callback)

  canSend: (fromDevice, toDevice, callback) =>
    process.exit(-1) unless callback?
    result = @checkLists fromDevice, toDevice, toDevice?.sendWhitelist, toDevice?.sendBlacklist, true
    @asyncCallback(null, result, callback)

  canConfigure: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    process.exit(-1) unless callback?

    return @asyncCallback(null, true, callback) if @checkLists fromDevice, toDevice, toDevice?.configureWhitelist, toDevice?.configureBlacklist, false

    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice

    return @asyncCallback(null, true, callback) if fromDevice.uuid == toDevice.uuid

    return @asyncCallback(null, toDevice.owner == fromDevice.uuid, callback) if toDevice.owner

    return @asyncCallback(null, true, callback) if util.sameLAN(fromDevice.ipAddress, toDevice.ipAddress)
    if message?.token
      return authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)

        @database
       )

    return @asyncCallback(null, false, callback)

module.exports = new SimpleAuth
