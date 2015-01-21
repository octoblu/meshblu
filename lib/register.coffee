_            = require 'lodash'
bcrypt       = require 'bcrypt'
crypto       = require 'crypto'
uuid         = require 'node-uuid'
updateDevice = require './updateDevice'

generateToken = ->
  return crypto.createHash('sha1').update((new Date()).valueOf().toString() + Math.random().toString()).digest('hex');

module.exports = (device={}, callback=_.noop, database=null) ->
  database ?= require './database'
  {devices} = database

  device = _.cloneDeep device

  device.uuid ?= uuid.v1()
  newDevice = {
    uuid: device.uuid
    online: false
  }

  devices.findOne {uuid: newDevice.uuid}, (error, existingDevice) =>
    return callback new Error('Device not registered 1') if error?
    return callback new Error('UUID is already registered.') if existingDevice?

    devices.insert newDevice, (error) =>
      return callback new Error('Device not registered 2') if error?

      device.token ?= generateToken()

      updateDevice newDevice.uuid, device, (error) =>
        return callback new Error('Device not registered 3') if error?

        callback null, device
      , database

  # device = _.cloneDeep device

  # device.uuid  ?= uuid.v1()
  # device.token ?= generateToken()
  # device.online = !!device.online

  # bcrypt.hash device.token, 8, (error, hashedToken) =>
  #   return callback error if error?
  #   params = _.cloneDeep device
  #   params.token = hashedToken


  #     devices.insert params, (error) =>
  #       return callback new Error('Device not registered') if error?
  #       callback null, device


