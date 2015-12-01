_ = require 'lodash'
async = require 'async'
request = require 'request'
UUID_REGEX = /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/i

class UUIDAliasResolver
  constructor: (options={}, {@redis, @aliasServerUri}) ->
    @redis ?= require '../lib/redis'

  resolve: (alias, callback) =>
    return callback null, alias if UUID_REGEX.test alias
    return callback null, alias unless @aliasServerUri?

    @_getAliasOrCache alias, (error, uuid) =>
      return callback error if error?
      callback null, uuid

  reverseLookup: (uuid, callback) =>
    return callback null unless @aliasServerUri?
    @_getReverseLookupOrCache uuid, (error, aliases) =>
      return callback error if error?
      callback null, aliases

  _cacheAlias: (alias, uuid, callback) =>
    @redis.setex "alias:#{alias}", 30, JSON.stringify(uuid: uuid), callback

  _getCache: (alias, callback) =>
    @redis.get "alias:#{alias}", (error, result) =>
      return callback error if error?
      return callback null unless result?
      return callback null, JSON.parse result

  _cacheReverseLookup: (uuid, aliases, callback) =>
    @redis.setex "alias:reverse:#{uuid}", 30, JSON.stringify(aliases: aliases), callback

  _getReverseLookupCache: (uuid, callback) =>
    @redis.get "alias:reverse:#{uuid}", (error, result) =>
      return callback error if error?
      return callback null unless result?
      return callback null, JSON.parse result

  _getAlias: (alias, callback) =>
    path = @aliasServerUri + "/?name=#{alias}"

    request.get path, json: true, (error, response, body) =>
      uuid = body?.uuid
      @_cacheAlias alias, uuid, (cacheError) =>
        return callback error if error?
        return callback error if cacheError?
        callback null, uuid

  _getAliasOrCache: (alias, callback) =>
    @_getCache alias, (error, result) =>
      return callback error if error?
      return callback null, result.uuid if result?

      @_getAlias alias, (error, uuid) =>
        return callback error if error?
        return callback null, uuid if uuid?

        return callback new Error 'Alias Not Found'

  _getReverseLookupOrCache: (uuid, callback) =>
    @_getReverseLookupCache uuid, (error, result) =>
      return callback error if error?
      return callback null, result.aliases if result?

      @_getReverseLookup uuid, (error, aliases) =>
        return callback error if error?
        callback null, aliases

  _getReverseLookup: (uuid, callback) =>
    path = @aliasServerUri + "/aliases/#{uuid}"

    request.get path, json: true, (error, response, body) =>
      return callback error if error?

      @_cacheReverseLookup uuid, body, (error) =>
        return callback error if error?
        callback null, body

module.exports = UUIDAliasResolver
