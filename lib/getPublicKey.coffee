_ = require 'lodash'

module.exports = (uuid, callback=_.noop, dependencies={}) ->
  return callback new Error('uuid is required for public key lookup') unless uuid?

  getDevice = dependencies.getDevice ? require './getDevice'

  getDevice uuid, (error, device) =>
    publicKey = device?.publicKey
    callback error, (publicKey ? null)
