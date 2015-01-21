_      = require 'lodash'
bcrypt = require 'bcrypt'
crypto = require 'crypto'
uuid   = require 'node-uuid'

generateToken = ->
  return crypto.createHash('sha1').update((new Date()).valueOf().toString() + Math.random().toString()).digest('hex');

module.exports = (device={}, callback=_.noop, database=null) ->
  {devices} = database ? require './database'
  device = _.cloneDeep device

  device.uuid  ?= uuid.v1()
  device.token ?= generateToken()
  device.online = !!device.online

  bcrypt.hash device.token, 8, (error, hashedToken) =>
    return callback error if error?
    params = _.cloneDeep device
    params.token = hashedToken

    devices.findOne {uuid: params.uuid}, (error, existingDevice) =>
      return callback new Error('Device not registered') if error?
      return callback new Error('UUID is already registered.') if existingDevice?

      devices.insert params, (error) =>
        return callback new Error('Device not registered') if error?
        callback null, device

