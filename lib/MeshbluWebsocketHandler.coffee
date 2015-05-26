_ = require 'lodash'
config = require '../config'
debug = require('debug')('meshblu:meshblu-websocket-handler')
{EventEmitter} = require 'events'

class MeshbluWebsocketHandler extends EventEmitter
  constructor: (dependencies={})->
    @authDevice = dependencies.authDevice ? require './authDevice'
    @SocketIOClient = dependencies.SocketIOClient ? require 'socket.io-client'
    @getSystemStatus = dependencies.getSystemStatus ? require './getSystemStatus'
    @securityImpl = dependencies.securityImpl ? require './getSecurityImpl'
    @getDevice = dependencies.getDevice ? require './getDevice'
    @updateFromClient = dependencies.updateFromClient ? require './updateFromClient'

  initialize: (@socket, request) =>
    @headers = request?.headers
    @socket.on 'message', @onMessage
    @socket.on 'close', @onClose
    @addListener 'status', @status
    @addListener 'identity', @identity
    @addListener 'update', @update
    @addListener 'subscribe', @subscribe
    @socketIOClient = @SocketIOClient('ws://localhost:' + config.messageBus.port)
    @socketIOClient.on 'message', @onSocketMessage

  identity: (data) =>
    data ?= {}
    {@uuid, @token} = data
    @authDevice @uuid, @token, (error, device) =>
      return @sendFrame 'notReady', message: 'unauthorized', status: 401 if error?
      @sendFrame 'ready', uuid: @uuid, token: @token, status: 200
      @socketIOClient.emit 'subscribe', @uuid
      @socketIOClient.emit 'subscribe', "#{@uuid}_bc"

  status: =>
    @getSystemStatus (status) =>
      @sendFrame 'status', status

  subscribe: (data) =>
    @authDevice @uuid, @token, (error, device) =>
      return @sendError error.message, ['subscribe', data] if error?
      @getDevice data.uuid, (error, subscribedDevice) =>
        return @sendError error.message, ['subscribe', data] if error?
        @securityImpl.canReceive device, subscribedDevice, (error, permission) =>
          return @sendError error.message, ['subscribe', data] if error?
          @socketIOClient.emit 'subscribe', "#{subscribedDevice.uuid}_bc"

          if subscribedDevice.owner? && subscribedDevice.owner == device.uuid
            @socketIOClient.emit 'subscribe', subscribedDevice.uuid

  unsubscribe: (data) =>
    @authDevice @uuid, @token, (error, device) =>
      return @sendError error.message, ['unsubscribe', data] if error?
      @socketIOClient.emit 'unsubscribe', "#{data.uuid}_bc"
      @socketIOClient.emit 'unsubscribe', data.uuid

  update: (data) =>
    @authDevice @uuid, @token, (error, device) =>
      return @sendError error.message, ['update', data] if error?
      @updateFromClient device, data

  # event handlers
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

  #socketio event handlers
  onSocketMessage: (data) =>
    @sendFrame 'message', data

module.exports = MeshbluWebsocketHandler
