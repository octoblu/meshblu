_ = require 'lodash'

generateAndStoreToken = (uuid, callback=_.noop, dependencies={}) =>
  Device = dependencies.Device ? require('./models/device')
  device = new Device uuid: uuid

  token = device.generateToken()
  device.storeToken token, (error) =>
    return callback error if error?
    callback null, token: token

module.exports = generateAndStoreToken
