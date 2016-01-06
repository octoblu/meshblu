_ = require 'lodash'

updateIfAuthorized = (fromDevice, query, params, options, callback, dependencies={}) ->
  securityImpl = dependencies.securityImpl ? require('./getSecurityImpl')
  Device = dependencies.Device ? require('./models/device')

  device = new Device uuid: query.uuid
  device.fetch (error, toDevice) =>
    securityImpl.canConfigure fromDevice, toDevice, query, (error, permission) =>
      return callback error if error?
      return callback new Error('Device does not have sufficient permissions for update') unless permission

      device.update params, options, (error) =>
        return callback error if error?
        callback()

#Figure it out. I dare you!
module.exports = module.exports = (fromDevice, query, params, rest...) ->
  [callback, dependencies] = rest
  [options, callback, dependencies] = rest if _.isPlainObject callback
  options ?= {}
  dependencies ?={}

  updateIfAuthorized fromDevice, query, params, options, callback, dependencies
