_ = require 'lodash'
async = require 'async'
request = require 'request'
UUID_REGEX = /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/i

class UUIDAliasResolver
  constructor: (options={}, {@redis, @aliasServerUri}) ->
    @aliasServerUri ?= 'https://alias.octoblu.com'

  resolve: (alias, callback) =>
    return callback null, alias if UUID_REGEX.test alias

    @_getAliasOrCache alias, (error, uuid) =>
      return callback error if error?
      callback null, uuid

  _cacheAlias: (alias, uuid, callback) =>
    @redis.setex "alias:#{alias}", 30, uuid, callback

  _getCache: (alias, callback) =>
    @redis.get "alias:#{alias}", callback

  _getAlias: (alias, callback) =>
    path = @aliasServerUri + "/?name=#{alias}"

    request.get path, json: true, (error, response, body) =>
      return callback error if error?

      uuid = body?.uuid
      return callback new Error 'Alias Not Found' unless uuid?

      @_cacheAlias alias, uuid, (error) =>
        return callback error if error?
        callback null, uuid

  _getAliasOrCache: (alias, callback) =>
    @_getCache alias, (error, uuid) =>
      return callback error if error?
      return callback null, uuid if UUID_REGEX.test uuid

      @_getAlias alias, (error, uuid) =>
        return callback error if error?
        return callback null, uuid if UUID_REGEX.test uuid

        return callback new Error 'Alias Not Found'

module.exports = UUIDAliasResolver
