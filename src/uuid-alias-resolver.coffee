UUID_REGEX = /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/i

class UUIDAliasResolver
  constructor: (options={}, {@redis}) ->

  resolve: (alias, callback) =>
    return callback null, alias if UUID_REGEX.test alias
    @redis.get "alias:#{alias}", (error, uuid) =>
      if UUID_REGEX.test uuid
        return callback null, uuid
      callback null, alias

module.exports = UUIDAliasResolver
