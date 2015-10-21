_ = require 'lodash'
config = require './../config'
redis = require './redis'
cacheDevice = require './cacheDevice'
findCachedDevice = require './findCachedDevice'
debug = require('debug')('meshblu:getDeviceWithToken')

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
