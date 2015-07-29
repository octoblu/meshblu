_      = require 'lodash'
async  = require 'async'
bcrypt = require 'bcrypt'
crypto = require 'crypto'
debug  = require('debug')('meshblu:model:device')

class Device
  constructor: (attributes={}, dependencies={}) ->
    @devices = dependencies.database?.devices ? require('../database').devices
    @getGeo = dependencies.getGeo ? require '../getGeo'
    @generateToken = dependencies.generateToken ? require '../generateToken'
    @clearCache = dependencies.clearCache ? require '../clearCache'
    @config = dependencies.config ? require '../../config'
    @set attributes
    {@uuid} = attributes

  fetch: (callback=->) =>
    if @fetch.cache?
      return _.defer callback, null, @fetch.cache

    @devices.findOne uuid: @uuid, (error, device) =>
      @fetch.cache = device
      unless device?
        error = new Error('Device not found')
      callback error, @fetch.cache

  storeToken: (token, callback=_.noop)=>
    @fetch (error, attributes) =>
      return callback error if error?

      hashedToken = @_hashToken token
      debug 'storeToken', token, hashedToken
      tokenData = createdAt: new Date()
      @update $set: {"meshblu.tokens.#{hashedToken}" : tokenData}, callback

  revokeToken: (token, callback=_.noop)=>
    @fetch (error, attributes) =>
      return callback error if error?

      hashedToken = @_hashToken token
      @update $unset : {"meshblu.tokens.#{hashedToken}"}, callback

  verifyToken: (token, callback=->) =>
    @verifyOGToken token, (error, verified) =>
      return callback error if error?
      return callback null, true if verified

      @verifyNewToken token, (error, verified) =>
        return callback error if error?
        return callback null, true if verified

        @verifyDeprecatedToken token, (error, verified) =>
          return callback error if error?
          return callback null, false unless verified
          @storeToken token, (error) =>
            return callback error if error?
            @revokeDeprecatedToken token, (error) =>
              return callback error if error?
              callback null, true

  verifyNewToken: (token, callback=->) =>
    hashedToken = @_hashToken token
    @devices.findOne uuid: @uuid, "meshblu.tokens.#{hashedToken}": {$exists: true}, (error, device) =>
      return callback error if error?
      callback null, !!device

  verifyOGToken: (ogToken, callback=->) =>
    debug "verifyOGToken: ", ogToken

    @fetch (error, attributes={}) =>
      return callback error, false if error?
      return callback null, false unless attributes.token?
      bcrypt.compare ogToken, attributes.token, (error, result) =>
        debug "verifyOGToken: bcrypt.compare results: #{error}, #{result}"
        callback null, result

  verifyDeprecatedToken: (token, callback=->) =>
    @fetch (error, attributes={}) =>
      return callback error if error?
      return callback null, false unless attributes.tokens?

      hashedTokens = _.pluck attributes.tokens, 'hash'

      compareToken = (hashedToken, callback=->) =>
        debug "compareToken: ", token, hashedToken
        bcrypt.compare token, hashedToken, (error, result) =>
          debug "bcrypt.compare results: #{error}, #{result}"
          callback(result)

      # this is faster than async.detect, srsly, trust me.
      async.detectSeries hashedTokens.reverse(), compareToken, (goodToken) =>
        callback null, goodToken?

  revokeDeprecatedToken: (token, callback=_.noop)=>
    @fetch (error, attributes) =>
      return callback error if error?

      compareToken = (hashedToken, callback=->) =>
        return callback true unless hashedToken?.hash?
        debug 'compareToken', token, hashedToken.hash
        bcrypt.compare token, hashedToken.hash, (error, result) =>
          debug 'result', error, result
          callback(result)

      tokens = attributes.tokens ? []

      async.rejectSeries tokens.reverse(), compareToken, (remainingTokens) =>
        @attributes.tokens = remainingTokens
        @save callback

  sanitize: (params) =>
    return params unless _.isObject(params) || _.isArray(params)

    return _.map params, @sanitize if _.isArray params

    params = _.omit params, (value, key) -> key[0] == '$'
    return _.mapValues params, @sanitize

  save: (callback=->) =>
    return callback @error unless @validate()
    async.series [
      @addGeo
      @addHashedToken
      @addOnlineSince
    ], (error) =>
      return callback error if error?
      debug 'save', @attributes
      @update $set: @attributes, callback

  set: (attributes)=>
    @attributes ?= {}
    @attributes = _.extend {}, @attributes, @sanitize(attributes)
    @attributes.online = !!@attributes.online if @attributes.online?
    @attributes.timestamp = new Date()

  validate: =>
    if @attributes.uuid? && @uuid != @attributes.uuid
      @error = new Error('Cannot modify uuid')
      return false

    return true

  update: (params, callback=->) =>
    params = _.cloneDeep params
    keys   = _.keys(params)

    if _.all(keys, (key) -> _.startsWith key, '$')
      params['$set'] ?= {}
      params['$set'].uuid = @uuid
    else
      params.uuid = @uuid

    debug 'update', @uuid, params

    @devices.update uuid: @uuid, params, (error) =>
      @clearCache @uuid, =>
        @fetch?.cache = null
        return callback @sanitizeError(error) if error?
        @_hashDevice (error) =>
          return callback @sanitizeError(error) if error?
          callback()

  _hashDevice: (callback=->) =>
    debug '_hashDevice', @uuid
    @devices.findOne uuid: @uuid, (error, data) =>
      return callback error if error?
      delete data.meshblu.hash if data?.meshblu?.hash
      params = $set :
        'meshblu.hash': @_hashToken JSON.stringify(data)
      debug 'updating hash', @uuid, params
      @devices.update uuid: @uuid, params, callback

  addGeo: (callback=->) =>
    return _.defer callback unless @attributes.ipAddress?

    @getGeo @attributes.ipAddress, (error, geo) =>
      @attributes.geo = geo
      callback()

  addHashedToken: (callback=->) =>
    token = @attributes.token
    return _.defer callback, null, null unless token?

    @fetch (error, device) =>
      return callback error if error?
      return callback null, null if device.token == token

      bcrypt.hash token, 8, (error, hashedToken) =>
        @attributes.token = hashedToken if hashedToken?
        callback error

  addOnlineSince: (callback=->) =>
    @fetch (error, device) =>
      return callback error if error?

      if !device.online && @attributes.online
        @attributes.onlineSince = new Date()

      callback()

  sanitizeError: (error) =>
    message = error
    message = error.message if _.isError error

    new Error message.replace("MongoError: ")

  _hashToken: (token) =>
    hasher = crypto.createHash 'sha256'
    hasher.update token
    hasher.update @uuid
    hasher.update @config.token
    hasher.digest 'base64'

module.exports = Device
