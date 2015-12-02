_      = require 'lodash'
async  = require 'async'
bcrypt = require 'bcrypt'
debug  = require('debug')('meshblu:authDevice')

module.exports = (uuid, token, callback=(->), dependencies={}) ->
  Device = dependencies.Device ? require './models/device'
  device = new Device {uuid: uuid}, {config: dependencies.config}
  device.verifyToken token, (error, verified) =>
    debug('verifyToken', error.stack) if error?
    return callback error if error?
    return callback new Error('Unable to find valid device') unless verified
    device.fetch (error, attributes) =>
      debug('fetch', error.stack) if error?
      return callback error if error?
      callback null, attributes
