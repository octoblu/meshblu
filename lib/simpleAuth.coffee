util = require "./util"
async = require 'async'
bcrypt = require "bcrypt"
_ = require "lodash"
UUIDAliasResolver = require '../src/uuid-alias-resolver'

class SimpleAuth

  constructor: (@dependencies={}) ->
    {aliasServerUri, @authDevice} = @dependencies
    @authDevice ?= require './authDevice'
    @uuidAliasResolver = new UUIDAliasResolver {}, {@redis, aliasServerUri}

  asyncCallback: (error, result, callback) =>
    # _.defer callback, error, result
    callback error, result

  _checkLists: (fromDevice, toDevice, whitelist, blacklist, openByDefault, callback) =>
    @_resolveList whitelist, (error, resolvedWhitelist) =>
      return callback error if error?

      @_resolveList blacklist, (error, resolvedBlacklist) =>
        return callback error if error?

        toDeviceAlias = toDevice.uuid
        fromDeviceAlias = fromDevice.uuid

        @uuidAliasResolver.resolve toDeviceAlias, (error, toDeviceUuid) =>
          return callback error if error?

          @uuidAliasResolver.resolve fromDeviceAlias, (error, fromDeviceUuid) =>
            return callback error if error?

            return callback null, true if toDeviceUuid == fromDeviceUuid

            return callback null, true if _.contains resolvedWhitelist, '*'

            return callback null, _.contains(resolvedWhitelist, fromDeviceUuid) if resolvedWhitelist?

            return callback null, !_.contains(resolvedBlacklist, fromDeviceUuid) if resolvedBlacklist?

            callback null, openByDefault

  canConfigure: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice

    @_checkLists fromDevice, toDevice, toDevice.configureWhitelist, toDevice.configureBlacklist, false, (error, inList) =>
      return callback error if error?
      return callback null, true if inList

      return @asyncCallback(null, true, callback) if fromDevice.uuid == toDevice.uuid

      if toDevice.owner?
        return @asyncCallback(null, true, callback) if toDevice.owner == fromDevice.uuid
      else
        return @asyncCallback(null, true, callback) if util.sameLAN(fromDevice.ipAddress, toDevice.ipAddress)

      if message?.token
        return @authDevice(
          toDevice.uuid
          message.token
          (error, result) =>
            return @asyncCallback(error, false, callback) if error?
            return @asyncCallback(null, result?, callback)
         )

      @asyncCallback(null, false, callback)

  canConfigureAs: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice

    if message?.token
      return @authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)
       )

    configureAsWhitelist = _.cloneDeep toDevice.configureAsWhitelist
    unless configureAsWhitelist
      configureAsWhitelist = []
      configureAsWhitelist.push toDevice.owner if toDevice.owner

    @_checkLists fromDevice, toDevice, configureAsWhitelist, toDevice.configureAsBlacklist, true, (error, inList) =>
      return callback error if error?
      callback null, inList

  canDiscover: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice

    @_checkLists fromDevice, toDevice, toDevice.discoverWhitelist, toDevice.discoverBlacklist, true, (error, inList) =>
      return callback error if error?
      return callback null, true if inList

      if message?.token
        return @authDevice(
          toDevice.uuid
          message.token
          (error, result) =>
            return @asyncCallback(error, false, callback) if error?
            return @asyncCallback(null, result?, callback)
         )

      @asyncCallback(null, false, callback)

  canDiscoverAs: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice

    if message?.token
      return @authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)
       )

    discoverAsWhitelist = _.cloneDeep toDevice.discoverAsWhitelist
    unless discoverAsWhitelist
      discoverAsWhitelist = []
      discoverAsWhitelist.push toDevice.owner if toDevice.owner

    @_checkLists fromDevice, toDevice, discoverAsWhitelist, toDevice.discoverAsBlacklist, true, (error, inList) =>
      return callback error if error?
      callback null, inList

  canReceive: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice

    if message?.token
      return @authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)
       )

    @_checkLists fromDevice, toDevice, toDevice.receiveWhitelist, toDevice.receiveBlacklist, true, (error, inList) =>
      return callback error if error?
      callback null, inList

  canReceiveAs: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice

    if message?.token
      return @authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)
       )

    receiveAsWhitelist = _.cloneDeep toDevice.receiveAsWhitelist
    unless receiveAsWhitelist
      receiveAsWhitelist = []
      receiveAsWhitelist.push toDevice.owner if toDevice.owner

    @_checkLists fromDevice, toDevice, receiveAsWhitelist, toDevice.receiveAsBlacklist, true, (error, inList) =>
      return callback error if error?
      callback null, inList

  canSend: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice

    if message?.token
      return @authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)
       )

    @_checkLists fromDevice, toDevice, toDevice.sendWhitelist, toDevice.sendBlacklist, true, (error, inList) =>
      return callback error if error?
      callback null, inList

  canSendAs: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice

    if message?.token
      return @authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)
       )

    sendAsWhitelist = _.cloneDeep toDevice.sendAsWhitelist
    unless sendAsWhitelist
      sendAsWhitelist = []
      sendAsWhitelist.push toDevice.owner if toDevice.owner

    @_checkLists fromDevice, toDevice, sendAsWhitelist, toDevice.sendAsBlacklist, true, (error, inList) =>
      return callback error if error?
      callback null, inList

  _resolveList: (list, callback) =>
    return callback null, list unless _.isArray list
    async.map list, @uuidAliasResolver.resolve, callback

module.exports = SimpleAuth
