_      = require 'lodash'
moment = require 'moment'
bcrypt = require 'bcrypt'

invalidKey = (value, key) -> key[0] == '$'

sanitize = (params) =>
  return params unless _.isObject(params) || _.isArray(params)

  return _.map params, sanitize if _.isArray params

  params = _.omit params, invalidKey
  return _.mapValues params, sanitize

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
  clearCache = dependencies.clearCache ? require './clearCache'
  getGeo = dependencies.getGeo ? require './getGeo'

  clearCache 'DEVICE_' + uuid

  params = setDefaults(sanitize(params))
  getGeo params.ipAddress, (error, geo) =>
    params.geo = geo if geo?

    hashTokenIfNeeded params.token, (error, hashedToken) =>
      params.token = hashedToken if hashedToken?

      devices.update {uuid: uuid}, {$set: params}, (error, result) =>
        return callback error if error?

        numberOfRecords = result?.n ? result
        return callback new Error 'device not updated' unless numberOfRecords == 1

        clearCache(uuid)

        getDevice uuid, callback
