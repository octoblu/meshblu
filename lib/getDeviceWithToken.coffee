_ = require 'lodash'
config = require './../config'
redis = require './redis'
cacheDevice = require './cacheDevice'
debug = require('debug')('meshblu:getDeviceWithToken')

findCachedDevice = (uuid, callback) ->
  unless config.redis && config.redis.host
    callback(null, null)
    return

  cachedKey = redis.CACHE_KEY + uuid

  debug 'checking redis cache', cachedKey
  redis.get cachedKey, (error, data) ->
    debug 'cache results', error, data
    if error
      callback error
      return

    data = JSON.parse data if data
    callback null, data

findDevice = (uuid, callback, database) ->
  debug 'findDevice', uuid
  database ?= require './database'
  devices = database.devices

  devices.findOne {uuid: uuid}, {_id: false}, (error, data) ->
    debug 'devices.findOne', uuid, error, data
    return callback new Error ('database error while finding a device') if error?
    if data
      cacheDevice data
    callback null, data

module.exports = (uuid, callback=_.noop, database=null) ->
  debug 'getDeviceWithToken', uuid
  deviceFound = (error, data) ->
    if error || !data
      callback
        error:
          uuid: uuid
          message: 'Device not found'
          code: 404
      return

    callback null, data

  findCachedDevice uuid, (error, data) ->
    return callback error if error

    return callback null, data if data?

    findDevice uuid, deviceFound, database
