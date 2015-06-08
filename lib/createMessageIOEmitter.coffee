config = require '../config'
redis = require './redis'
MeshbluIOEmitter = require './messageIOEmitter'

module.exports = (io) =>
  meshbluIOEmitter = new MeshbluIOEmitter
  if config.redis?.host
    redisIoEmitter = require('socket.io-emitter')(redis.client)
    meshbluIOEmitter.addEmitter redisIoEmitter
  else
    meshbluIOEmitter.addEmitter io

  return meshbluIOEmitter.emit
