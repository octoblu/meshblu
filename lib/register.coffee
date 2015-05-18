_             = require 'lodash'
debug         = require('debug')('meshblu:register')
generateToken = require './generateToken'
logEvent      = require './logEvent'

module.exports = (device={}, callback=_.noop, dependencies={}) ->
  uuid         = dependencies.uuid || require 'node-uuid'
  database     = dependencies.database ? require './database'
  updateDevice = dependencies.updateDevice ? require './updateDevice'
  {devices}    = database

  device = _.cloneDeep device

  newDevice =
    uuid: uuid.v4()
    online: false

  debug "registering", device

  devices.insert newDevice, (error) =>
    debug 'inserted', error
    return callback new Error('Device not registered') if error?

    device.token ?= generateToken()
    device.discoverWhitelist ?= [device.owner] if device.owner

    debug 'about to update device', device
    updateDevice newDevice.uuid, device, (error, savedDevice) =>
      return callback new Error('Device not updated') if error?

      logEvent 400, savedDevice
      savedDevice.token = device.token

      callback null, savedDevice
