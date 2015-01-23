_ = require 'lodash'
config = require './../config'
redis = require './redis'
cacheDevice = require './cacheDevice'

findCachedDevice = (uuid, callback) ->
  unless config.redis && config.redis.host
    callback(null, null)
    return

  redis.get 'DEVICE_' + uuid, (error, data) ->
    if error
      callback error
      return

    data = JSON.parse data if data
    callback null, data

findDevice = (uuid, callback, database) ->
  database ?= require './database'
  devices = database.devices

  devices.findOne {uuid: uuid}, (error, data) ->
    if data
      delete data.token
      delete data._id
      cacheDevice data
    callback null, data

module.exports = (uuid, callback=_.noop, database=null) ->
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
    if error
      callback error
      return

    if data
      callback null, data
      return

    findDevice uuid, deviceFound, database
