_ = require 'lodash'
debug = require('debug')('meshblu:meshblu-websocket-handler')
{EventEmitter} = require 'events'

class MeshbluWebsocketHandler extends EventEmitter
  constructor: (dependencies={})->
    @authDevice = dependencies.authDevice ? require './authDevice'
    @getSystemStatus = dependencies.getSystemStatus ? require './getSystemStatus'
    @updateFromClient = dependencies.updateFromClient ? require './updateFromClient'

  initialize: (@socket, request) =>
    @headers = request?.headers
    @socket.on 'message', @onMessage
    @socket.on 'close', @onClose
    @addListener 'status', @status
    @addListener 'identity', @identity
    @addListener 'update', @update
    @addListener 'subscribe', @subscribe

  identity: (data) =>
    data ?= {}
    {@uuid, @token} = data
    @authDevice @uuid, @token, (error, device) =>
      return @sendFrame 'notReady', message: 'unauthorized', status: 401 if error?
      @sendFrame 'ready', uuid: @uuid, token: @token, status: 200

  status: =>
    @getSystemStatus (status) =>
      @sendFrame 'status', status

  subscribe: (data) =>
    @authDevice @uuid, @token, (error, device) =>
      return @sendError error.message, ['subscribe', data] if error?

  update: (data) =>
    @authDevice @uuid, @token, (error, device) =>
      return @sendError error.message, ['update', data] if error?
      @updateFromClient device, data

  onClose: (event) ->
    debug 'on.close'
    @socket = null

  onMessage: (event) =>
    debug 'onMessage', event.data
    @parseFrame event.data, (error, type, data) =>
      @sendError error.message, event.data if error?
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

  sendError: (message, frame) =>
    debug 'sendError', message
    @sendFrame 'error', message: message, frame: frame

module.exports = MeshbluWebsocketHandler
