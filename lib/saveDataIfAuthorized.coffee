_ = require 'lodash'

module.exports = (sendMessage, fromDevice, toDeviceUuid, params, callback=_.noop, dependencies={}) ->
  securityImpl = dependencies.securityImpl ? require './getSecurityImpl'
  getDevice = dependencies.getDevice ? require './getDevice'
  dataDB = dependencies.dataDB ? require('./database').data
  logEvent = dependencies.logEvent ? require './logEvent'
  moment = dependencies.moment ? require 'moment'

  getDevice toDeviceUuid, (error, toDevice) =>
    return callback new Error(error.error.message) if error?
    securityImpl.canSend fromDevice, toDevice, params, (error, permission) =>
      return callback error if error?
      return callback new Error('Device does not have sufficient permissions to save data') unless permission

      data = _.omit _.cloneDeep(params), 'token'
      data.uuid = toDeviceUuid
      data.timestamp ?= moment().toISOString()
      data.timestamp = moment(data.timestamp).toISOString()
      _.each data, (value, key) ->
        try
          data[key] = JSON.parse(value).toString()
        catch e
      logEvent 700, data

      dataDB.insert data, (error, saved) ->
        return callback error if error?

        message =
          devices: ['*']
          payload: data
        sendMessage toDevice, message

        callback null, saved
