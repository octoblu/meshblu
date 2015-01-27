util = require "./util"
bcrypt = require "bcrypt"
_ = require "lodash"

checkLists = (fromDevice, toDevice, whitelist, blacklist, openByDefault) ->
  return false if !fromDevice or !toDevice

  return true if toDevice.uuid == fromDevice.uuid

  return true if toDevice.owner == fromDevice.uuid

  return  _.contains(whitelist, fromDevice.uuid) if whitelist and whitelist.length

  return !_.contains(blacklist, fromDevice.uuid) if blacklist and blacklist.length

  openByDefault

module.exports =
  canDiscover: (fromDevice, toDevice) ->
    checkLists fromDevice, toDevice, toDevice?.discoverWhitelist, toDevice?.discoverBlacklist, true

  canReceive: (fromDevice, toDevice) ->
    checkLists fromDevice, toDevice, toDevice?.receiveWhitelist, toDevice?.receiveBlacklist, true

  canSend: (fromDevice, toDevice) ->
    checkLists fromDevice, toDevice, toDevice?.sendWhitelist, toDevice?.sendBlacklist, true

  canConfigure: (fromDevice, toDevice, message) ->
    return false if !fromDevice || !toDevice

    if toDevice.token && message && message.token
      return true if bcrypt.compareSync message.token, toDevice.token

    return true if fromDevice.uuid == toDevice.uuid

    return toDevice.owner == fromDevice.uuid if toDevice.owner

    return util.sameLAN fromDevice.ipAddress, toDevice.ipAddress
