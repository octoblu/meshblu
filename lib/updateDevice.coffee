_      = require 'lodash'
moment = require 'moment'
bcrypt = require 'bcrypt'
clearCache = require './clearCache'

NOT_UPDATED_ERROR = new Error 'device not updated'

invalidKey = (value, key) -> key[0] == '$'

sanitize = (params) =>
  return params unless _.isObject(params) || _.isArray(params)

  params = _.omit params, invalidKey
  _.mapValues params, sanitize

hashTokenIfNeeded = (token=null, callback) =>
  return _.defer callback, null, null unless token?
  bcrypt.hash token, 8, callback

setDefaults = (params) =>
  params.online = !!params.online if params.online?
  params.timestamp = moment().toISOString()
  params

module.exports = (uuid, params={}, callback=_.noop, dependencies={})->
  {devices} = dependencies.database ? require './database'
  getDevice = dependencies.getDevice ? require './getDevice'

  params = setDefaults(sanitize(params))

  hashTokenIfNeeded params.token, (error, hashedToken) =>
    params.token = hashedToken if hashedToken?

    devices.update {uuid: uuid}, {$set: params}, (error, result) =>
      return callback error if error?

      numberOfRecords = result?.n
      return callback NOT_UPDATED_ERROR unless numberOfRecords == 1

      clearCache(uuid)

      getDevice uuid, (error, device) =>
        callback null, device
