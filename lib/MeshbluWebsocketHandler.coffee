_ = require 'lodash'
debug = require('debug')('meshblu:meshblu-websocket-handler')
{EventEmitter} = require 'events'

class MeshbluWebsocketHandler extends EventEmitter

  initialize: (@socket, request) =>
    @socket.on 'message', (event) =>
      debug 'on.message', event.data
      @parseFrame event.data, (error, type, data) =>
        @sendError error.message if error?
        @emit type, data

    @socket.on 'close', (event) ->
      @socket = null

  parseFrame: (frame, callback=->) =>
    try frame = JSON.parse frame
    if _.isArray(frame) && frame.length > 1
      return callback null, frame...

    callback new Error 'invalid frame, must be in the form of [type, data]'

  sendFrame: (type, data) =>
    frame = [type, data]
    @socket.send JSON.stringify frame

  sendError: (message) =>
    @sendFrame 'error', message: message

module.exports = MeshbluWebsocketHandler
