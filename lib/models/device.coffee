_      = require 'lodash'
async  = require 'async'
bcrypt = require 'bcrypt'
crypto = require 'crypto'
debug  = require('debug')('meshblu:model:device')
Publisher = require '../Publisher'

publisher = new Publisher

class Device
  constructor: (attributes={}, dependencies={}) ->
    @devices = dependencies.database?.devices ? require('../database').devices
    @getGeo = dependencies.getGeo ? require '../getGeo'
    @generateToken = dependencies.generateToken ? require '../generateToken'
    @clearCache = dependencies.clearCache ? require '../clearCache'
    @config = dependencies.config ? require '../../config'
    @redis = dependencies.redis ? require '../redis'
    @findCachedDevice = dependencies.findCachedDevice ? require '../findCachedDevice'
    @cacheDevice = dependencies.cacheDevice ? require '../cacheDevice'
    @set attributes
    {@uuid} = attributes

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
        @_storeTokenInCache hashedToken if hashedToken?
        callback error

  addOnlineSince: (callback=->) =>
    @fetch (error, device) =>
      return callback error if error?

      if !device.online && @attributes.online
        @attributes.onlineSince = new Date()

      callback()

  fetch: (callback=->) =>
    return _.defer callback, null, @fetch.cache if @fetch.cache?

    @findCachedDevice @uuid, (error, device) =>
      return callback error if error?
      if device?
        @fetch.cache = device
        return callback null, device

      @devices.findOne uuid: @uuid, {_id: false}, (error, device) =>
        @fetch.cache = device
        return callback new Error('Device not found') unless device?
        @cacheDevice device
        callback null, @fetch.cache

  generateAndStoreTokenInCache: (callback=->)=>
    token = @generateToken()
    hashedToken = @_hashToken token
    @_storeTokenInCache hashedToken, (error) =>
      return callback error if error?
      callback null, token

  removeTokenFromCache: (token, callback=->) =>
    return callback null, false unless @redis?.srem?
    hashedToken = @_hashToken token
    @redis.srem "tokens:#{@uuid}", hashedToken, callback

  resetToken: (callback) =>
    newToken = @generateToken()
    @set token: newToken
    @save (error) =>
      return callback error if error?
      @_clearTokenCache()
      callback null, newToken

  revokeToken: (token, callback=_.noop)=>
    @fetch (error, attributes) =>
      return callback error if error?

      try
        hashedToken = @_hashToken token
      catch error
        return callback error

      @removeTokenFromCache token
      @update $unset : {"meshblu.tokens.#{hashedToken}"}, callback

  sanitize: (params) =>
    return params unless _.isObject(params) || _.isArray(params)

    return _.map params, @sanitize if _.isArray params

    params = _.omit params, (value, key) -> key[0] == '$'
    return _.mapValues params, @sanitize

  sanitizeError: (error) =>
    message = error?.message ? error
    message = "Unknown error" unless _.isString message

    new Error message.replace("MongoError: ")

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

  storeToken: (token, callback=_.noop)=>
    @fetch (error, attributes) =>
      return callback error if error?

      try
        hashedToken = @_hashToken token
      catch error
        return callback error

      debug 'storeToken', token, hashedToken
      tokenData = createdAt: new Date()
      @_storeTokenInCache hashedToken
      @update $set: {"meshblu.tokens.#{hashedToken}" : tokenData}, callback

  validate: =>
    if @attributes.uuid? && @uuid != @attributes.uuid
      @error = new Error('Cannot modify uuid')
      return false

    return true

  verifyRootToken: (ogToken, callback=->) =>
    debug "verifyRootToken: ", ogToken

    @fetch (error, attributes={}) =>
      return callback error, false if error?
      return callback null, false unless attributes.token?
      bcrypt.compare ogToken, attributes.token, (error, verified) =>
        return callback error if error?
        debug "verifyRootToken: bcrypt.compare results: #{error}, #{verified}"
        @_storeTokenInCache @_hashToken(ogToken) if verified
        callback null, verified

  verifySessionToken: (token, callback=->) =>
    try
      hashedToken = @_hashToken token
    catch error
      return callback error

    @fetch (error, attributes) =>
      return callback error if error?

      verified = attributes?.meshblu?.tokens?[hashedToken]?
      @_storeTokenInCache hashedToken if verified
      callback null, verified

  verifyToken: (token, callback=->) =>
    return callback new Error('No token provided') unless token?

    @_isTokenInBlacklist token, (error, blacklisted) =>
      return callback error if error?
      return callback null, false if blacklisted

      @_verifyTokenInCache token, (error, verified) =>
        return callback error if error?
        return callback null, true if verified

        @verifySessionToken token, (error, verified) =>
          return callback error if error?
          return callback null, true if verified

          @verifyRootToken token, (error, verified) =>
            return callback error if error?
            return callback null, true if verified

            @_storeInvalidTokenInBlacklist token
            return callback null, false

  update: (params, callback=->) =>
    params = _.cloneDeep params
    keys   = _.keys(params)

    if _.all(keys, (key) -> _.startsWith key, '$')
      params['$set'] ?= {}
      params['$set'].uuid = @uuid
    else
      params.uuid = @uuid

    debug 'update', @uuid, params

    @devices.update uuid: @uuid, params, (error, result) =>
      return callback @sanitizeError(error) if error?

      @clearCache @uuid, =>
        @fetch.cache = null
        @_hashDevice (error) =>
          @_sendConfig()
          return callback @sanitizeError(error) if error?
          callback()

  _clearTokenCache: (callback=->) =>
    return callback null, false unless @redis?.del?
    @redis.del "tokens:#{@uuid}", callback

  _hashDevice: (callback=->) =>
    debug '_hashDevice', @uuid
    @devices.findOne uuid: @uuid, (error, data) =>
      return callback error if error?
      delete data.meshblu.hash if data?.meshblu?.hash
      try
        hashedToken = @_hashToken JSON.stringify(data)
      catch error
        return callback error
      params = $set :
        'meshblu.hash': hashedToken
      debug 'updating hash', @uuid, params
      @devices.update uuid: @uuid, params, callback

  _hashToken: (token) =>
    throw new Error 'Invalid Device UUID' unless @uuid?

    hasher = crypto.createHash 'sha256'
    hasher.update token
    hasher.update @uuid
    hasher.update @config.token
    hasher.digest 'base64'

  _sendConfig: =>
    @fetch (error, attributes) =>
      publisher.publish 'config', @uuid, attributes

  _storeTokenInCache: (token, callback=->) =>
    return callback null, false unless @redis?.sadd?
    @redis.sadd "tokens:#{@uuid}", token, callback

  _storeInvalidTokenInBlacklist: (token, callback=->) =>
    return callback null, false unless @redis?.sadd?
    @redis.sadd "tokens:blacklist:#{@uuid}", token, callback

  _verifyTokenInCache: (token, callback=->) =>
    return callback null, false unless @redis?.sismember?
    hashedToken = @_hashToken token
    @redis.sismember "tokens:#{@uuid}", hashedToken, callback

  _isTokenInBlacklist: (token, callback=->) =>
    return callback null, false unless @redis?.sismember?
    @redis.sismember "tokens:blacklist:#{@uuid}", token, callback

module.exports = Device
