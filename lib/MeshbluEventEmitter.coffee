debug = require('debug')('meshblu:MeshbluEventEmitter')

class MeshbluEventEmitter
  constructor: (@meshbluUuid, @uuids, @sendMessage) ->

  emit: (eventType, data) =>
    message =
      devices: @uuids
      topic: eventType
      payload: data
    @sendMessage uuid: @meshbluUuid, message

module.exports = MeshbluEventEmitter
