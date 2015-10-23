Device = require './models/device'

module.exports = (uuid, params={}, callback=_.noop, dependencies={})->
  device = new Device uuid: uuid, dependencies
  device.set params

  device.save (error) =>
    return callback error if error?
    device.fetch callback
