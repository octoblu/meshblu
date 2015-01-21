_            = require 'lodash'
bcrypt       = require 'bcrypt'
crypto       = require 'crypto'
uuid         = require 'node-uuid'

generateToken = ->
  return crypto.createHash('sha1').update((new Date()).valueOf().toString() + Math.random().toString()).digest('hex');

module.exports = (device={}, callback=_.noop, dependencies={}) ->
  database     = dependencies.database ? require './database'
  updateDevice = dependencies.updateDevice ? require './updateDevice'
  {devices}    = database

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

      updateDevice newDevice.uuid, device, (error, savedDevice) =>
        return callback new Error('Device not registered 3') if error?
        savedDevice.token = device.token

        callback null, savedDevice
