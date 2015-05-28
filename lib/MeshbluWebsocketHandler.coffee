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
    @getDevices = dependencies.getDevices ? require './getDevices'
    @sendMessage = dependencies.sendMessage
    @updateFromClient = dependencies.updateFromClient ? require './updateFromClient'

  initialize: (@socket, request) =>
    @headers = request?.headers
    @socket.on 'message', @onMessage
    @socket.on 'close', @onClose
    @addListener 'status', @status
    @addListener 'identity', @identity
    @addListener 'update', @update
    @addListener 'subscribe', @subscribe
    @addListener 'unsubscribe', @unsubscribe
    @addListener 'message', @message
    @addListener 'device', @device
    @addListener 'devices', @devices
    @socketIOClient = @SocketIOClient('ws://localhost:' + config.messageBus.port)
    @socketIOClient.on 'message', @onSocketMessage

  device: (data) =>
    return @deviceWithToken data if data.token

    @authDevice @uuid, @token, (error, device) =>
      debug 'device', data
      return @sendError error.message, ['device', data] if error?
      @getDevice data.uuid, (error, foundDevice) =>
        return @sendError error.message, ['device', data] if error?
        @securityImpl.canDiscover device, foundDevice, (error, permission) =>
          @sendFrame 'device', foundDevice

  devices: (data) =>
    @authDevice @uuid, @token, (error, device) =>
      debug 'devices', data
      return @sendError error.message, ['devices', data] if error?
      @getDevices device, data, (error, foundDevices) =>
        return @sendError error.message, ['devices', data] if error?
        @sendFrame 'devices', foundDevices

  deviceWithToken: (data) =>
    @authDevice data.uuid, data.token, (error, authedDevice) =>
      debug 'deviceWithToken', data
      return @sendError error?.message, ['device', data] if error? || !authedDevice?
      delete authedDevice.token
      @sendFrame 'device', authedDevice

  identity: (data) =>
    data ?= {}
    {@uuid, @token} = data
    @authDevice @uuid, @token, (error, device) =>
      return @sendFrame 'notReady', message: 'unauthorized', status: 401 if error?
      @sendFrame 'ready', uuid: @uuid, token: @token, status: 200
      @setOnlineStatus device, true
      @socketIOClient.emit 'subscribe', @uuid
      @socketIOClient.emit 'subscribe', "#{@uuid}_bc"

  message: (data) =>
    @authDevice @uuid, @token, (error, device) =>
      debug 'message', data
      return @sendError error.message, ['message', data] if error?
      @sendMessage device, data

  mydevices: (data) =>
    @authDevice @uuid, @token, (error, device) =>
      debug 'mydevices', data
      return @sendError error.message, ['mydevices', data] if error?
      data.owner = device.uuid
      @getDevices device, data, (error, foundDevices) =>
        return @sendError error.message, ['mydevices', data] if error?
        @sendFrame 'mydevices', foundDevices

  whoami: (data) =>
    @authDevice @uuid, @token, (error, device) =>
      return @sendError error.message, ['whoami', data] if error?
      @sendFrame 'whoami', device

  setOnlineStatus: (device, online) =>
    message =
      devices: '*',
      topic: 'device-status',
      payload:
        online: online
    @sendMessage device, message

  status: =>
    @getSystemStatus (status) =>
      @sendFrame 'status', status

  subscribe: (data) =>
    return @subscribeWithToken data if data.token

    @authDevice @uuid, @token, (error, device) =>
      debug 'subscribe', data
      return @sendError error.message, ['subscribe', data] if error?
      @getDevice data.uuid, (error, subscribedDevice) =>
        return @sendError error.message, ['subscribe', data] if error?
        @securityImpl.canReceive device, subscribedDevice, (error, permission) =>
          return @sendError error.message, ['subscribe', data] if error?
          @socketIOClient.emit 'subscribe', "#{subscribedDevice.uuid}_bc"

          if subscribedDevice.owner? && subscribedDevice.owner == device.uuid
            @socketIOClient.emit 'subscribe', subscribedDevice.uuid

  subscribeWithToken: (data) =>
    @authDevice data.uuid, data.token, (error, authedDevice) =>
      debug 'subscribeWithToken', data
      return @sendError error?.message, ['subscribe', data] if error? || !authedDevice?
      @socketIOClient.emit 'subscribe', authedDevice.uuid

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
  onClose: (event) =>
    debug 'on.close'
    @authDevice @uuid, @token, (error, device) =>
      return if error?
      @setOnlineStatus device, false
      @socketIOClient.emit 'unsubscribe', @uuid
      @socketIOClient.emit 'unsubscribe', "#{@uuid}_bc"
      @socket = null
      @socketIOClient = null

  onMessage: (event) =>
    debug 'onMessage', event.data
    @parseFrame event.data, (error, type, data) =>
      @sendError error.message, event.data if error?
      @emit type, data

  # internal methods
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
