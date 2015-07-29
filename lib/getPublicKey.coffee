_ = require 'lodash'

module.exports = (uuid, callback=_.noop, dependencies={}) ->
  return callback new Error('uuid is required for public key lookup') unless uuid?

  getDevice = dependencies.getDevice ? require './getDevice'

  getDevice uuid, (error, device) =>
    return callback new Error(error.error.message) if error?

    publicKey = device?.publicKey
    callback null, (publicKey ? null)
