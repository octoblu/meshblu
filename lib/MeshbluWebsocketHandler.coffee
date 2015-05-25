_ = require 'lodash'
debug = require('debug')('meshblu:meshblu-websocket-handler')
{EventEmitter} = require 'events'

class MeshbluWebsocketHandler extends EventEmitter
  constructor: (dependencies={})->
    @authDevice = dependencies.authDevice ? require './authDevice'
    @getSystemStatus = dependencies.getSystemStatus ? require './getSystemStatus'

  initialize: (@socket, request) =>
    @headers = request?.headers
    @socket.on 'message', @onMessage
    @socket.on 'close', @onClose
    @addListener 'status', @status

  identity: (data) =>
    data ?= {}
    {uuid, token} = data
    @authDevice uuid, token, (error, device) =>
      return @sendFrame 'notReady', message: 'unauthorized', status: 401 if error?
      @sendFrame 'ready', uuid: device.uuid, token: data.token, status: 200

  status: =>
    @getSystemStatus (status) =>
      @sendFrame 'status', status

  onClose: (event) ->
    debug 'on.close', event
    @socket = null

  onMessage: (event) =>
    debug 'onMessage', event.data
    @parseFrame event.data, (error, type, data) =>
      @sendError error.message if error?
      @emit type, data

  parseFrame: (frame, callback=->) =>
    try frame = JSON.parse frame
    debug 'parseFrame', frame
    if _.isArray(frame) && frame.length
      return callback null, frame...

    callback new Error 'invalid frame, must be in the form of [type, data]'

  sendFrame: (type, data) =>
    frame = [type, data]
    debug 'sendFrame', frame
    @socket.send JSON.stringify frame

  sendError: (message) =>
    debug 'sendError', message
    @sendFrame 'error', message: message

module.exports = MeshbluWebsocketHandler
