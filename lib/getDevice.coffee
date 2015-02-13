getDeviceWithToken = require './getDeviceWithToken'

module.exports = (uuid, callback=_.noop, database=null) ->
  deviceFound = (error, data) ->
    delete data.token if data
    callback error, data

  getDeviceWithToken uuid, deviceFound, database
