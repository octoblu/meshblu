_ = require 'lodash'
debug = require('debug')('meshblu:MeshbluEventEmitter')

class MeshbluEventEmitter
  constructor: (@meshbluUuid, @uuids, @sendMessage, dependencies={}) ->
    @Date = dependencies.Date ? Date

  emit: (eventType, data={}) =>
    data = _.extend _timestamp: (new @Date).toJSON(), data

    message =
      devices: @uuids
      topic: eventType
      payload: data
    @sendMessage uuid: @meshbluUuid, message

  log: (event, didError, data) =>
    event = "#{event}-error" if didError
    @emit event, data

module.exports = MeshbluEventEmitter
