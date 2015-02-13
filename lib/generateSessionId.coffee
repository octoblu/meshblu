_ = require 'lodash'

getSessionId = (uuid, callback=_.noop, dependencies={}) =>
  Device = dependencies.Device ? require('./models/device')
  device = new Device uuid: uuid

  sessionId = device.generateSessionId()
  device.storeSessionId sessionId, (error) =>
    return callback error if error?
    callback null, sessionId: sessionId

module.exports = getSessionId
