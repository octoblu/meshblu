_ = require 'lodash'
config = require '../config'
redis = require './redis'
debug = require('debug')('meshblu:message-io-emitter')

class MessageIOEmitter
  constructor: (dependencies={}) ->
    @emitters = []

  addEmitter: (emitter) =>
    @emitters.push emitter

  emit: (channel, topic, data) =>
    _.each @emitters, (emitter) ->
      debug 'emit', channel, topic, data
      emitter.in(channel).emit(topic, data)

module.exports = MessageIOEmitter
