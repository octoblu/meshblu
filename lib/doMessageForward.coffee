_ = require 'lodash'
messageIOEmitter = require('./createMessageIOEmitter')();
async = require 'async'

module.exports = (forwarders=[], message, fromUuid, callback=_.noop, dependencies={}) ->
  async.map forwarders, (forwarder, cb=->) =>
    message.devices = [forwarder]
    message.fromUuid = fromUuid
    messageIOEmitter forwarder, 'message', message
    cb null
  , (error) =>
    callback error
