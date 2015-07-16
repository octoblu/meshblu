config = require '../config'
redis = require './redis'
MessageIOEmitter = require './messageIOEmitter'
debug = require('debug')('meshblu:create-message-io-emitter')

module.exports = (io) =>
  messageIOEmitter = new MessageIOEmitter
  if config.redis?.host
    debug 'adding redis emitter'
    redisIoEmitter = require('socket.io-emitter')(redis.client)
    messageIOEmitter.addEmitter redisIoEmitter
  else
    debug 'adding io emitter'
    messageIOEmitter.addEmitter io

  return messageIOEmitter.emit
