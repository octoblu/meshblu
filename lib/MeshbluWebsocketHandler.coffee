_ = require 'lodash'
config = require '../config'
debug = require('debug')('meshblu:meshblu-websocket-handler')
{EventEmitter} = require 'events'
uuid = require 'node-uuid'
subscribeToMessageIO = require './subscribeToMessageIO'

class MeshbluWebsocketHandler extends EventEmitter
  constructor: (dependencies={})->
    @authDevice = dependencies.authDevice ? require './authDevice'
    @SocketIOClient = dependencies.SocketIOClient ? require 'socket.io-client'
    @getSystemStatus = dependencies.getSystemStatus ? require './getSystemStatus'
    @securityImpl = dependencies.securityImpl ? require './getSecurityImpl'
    @getDevice = dependencies.getDevice ? require './getDevice'
    @getDevices = dependencies.getDevices ? require './getDevices'
    @registerDevice = dependencies.registerDevice ? require './register'
    @unregisterDevice = dependencies.unregisterDevice ? require './unregister'
    @sendMessage = dependencies.sendMessage
    @updateFromClient = dependencies.updateFromClient ? require './updateFromClient'
    @throttles = dependencies.throttles ? require './getThrottles'

  initialize: (@socket, request) =>
    @socket.id = uuid.v4()
    @headers = request?.headers

    @socket.on 'close', @onClose
    @socket.on 'message', @onMessage

    @addListeners()

    @socketIOClient = @SocketIOClient('ws://localhost:' + config.messageBus.port)
    @socketIOClient.on 'message', @onSocketMessage
    @socketIOClient.connect()

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
      return @sendError error.message, event.data if error?
      @rateLimit @socket.id, type, (error) =>
        return @sendError error.message, event.data, 429 if error?
        @emit type, data

  # message handlers
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
      @getDevices device, data, null, (foundDevices) =>
        @sendFrame 'devices', foundDevices

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

  mydevices: (data={}) =>
    @authDevice @uuid, @token, (error, device) =>
      debug 'mydevices', data
      return @sendError error.message, ['mydevices', data] if error?
      data.owner = device.uuid
      @getDevices device, data, null, (foundDevices) =>
        return @sendError error.message, ['mydevices', data] if error?
        @sendFrame 'mydevices', foundDevices

  register: (data) =>
    debug 'register', data
    @registerDevice data, (error, device) =>
      return @sendError error.message, ['register', data] if error?
      @sendFrame 'registered', device

  status: =>
    @getSystemStatus (status) =>
      @sendFrame 'status', status

  subscribe: (data) =>
    return @subscribeWithToken data if data.token

    subscriptionTypes = []

    @authDevice @uuid, @token, (error, device) =>
      debug 'subscribe', data
      return @sendError error.message, ['subscribe', data] if error?
      @getDevice data.uuid, (error, subscribedDevice) =>
        return @sendError error.message, ['subscribe', data] if error?
        @securityImpl.canReceive device, subscribedDevice, (error, permission) =>
          return @sendError error.message, ['subscribe', data] if error?
          subscriptionTypes.push 'broadcast' if permission

          if subscribedDevice.owner? && subscribedDevice.owner == device.uuid
            subscriptionTypes.push 'received'
            subscriptionTypes.push 'sent'

          subscribeToMessageIO @socketIOClient, subscribedDevice.uuid, data.types || subscriptionTypes

  unsubscribe: (data) =>
    return @unsubscribeWithToken data if data.token

    @authDevice @uuid, @token, (error, device) =>
      return @sendError error.message, ['unsubscribe', data] if error?
      @socketIOClient.emit 'unsubscribe', "#{data.uuid}_sent"
      @socketIOClient.emit 'unsubscribe', "#{data.uuid}_bc"
      @socketIOClient.emit 'unsubscribe', data.uuid

  unregister: (data) =>
    debug 'unregister', data
    return @unregisterWithToken data if data.token

    @authDevice @uuid, @token, (error, device) =>
      return @sendError error.message, ['unregister', data] if error?
      @unregisterDevice device, data.uuid
      @sendFrame 'unregistered', uuid: data.uuid

  update: (data) =>
    @authDevice @uuid, @token, (error, device) =>
      return @sendError error.message, ['update', data] if error?
      @updateFromClient device, data
      @sendFrame 'updated', uuid: data.uuid

  whoami: (data) =>
    @authDevice @uuid, @token, (error, device) =>
      return @sendError error.message, ['whoami', data] if error?
      @sendFrame 'whoami', device

  # internal methods
  addListeners: =>
    @addListener 'device', @device
    @addListener 'devices', @devices
    @addListener 'identity', @identity
    @addListener 'message', @message
    @addListener 'mydevices', @mydevices
    @addListener 'register', @register
    @addListener 'status', @status
    @addListener 'subscribe', @subscribe
    @addListener 'update', @update
    @addListener 'unsubscribe', @unsubscribe
    @addListener 'unregister', @unregister
    @addListener 'whoami', @whoami

  rateLimit: (id, type, callback=->) =>
    throttle = @throttles[type] ? @throttles.query
    callback() unless throttle?
    throttle.rateLimit id, (error, isLimited) =>
      debug 'rateLimit', id, type, isLimited
      return callback error if error?
      return callback new Error('request exceeds rate limit') if isLimited
      callback()

  deviceWithToken: (data) =>
    @authDevice data.uuid, data.token, (error, authedDevice) =>
      debug 'deviceWithToken', data
      return @sendError error?.message, ['device', data] if error? || !authedDevice?
      delete authedDevice.token
      @sendFrame 'device', authedDevice

  parseFrame: (frame, callback=->) =>
    try frame = JSON.parse frame
    debug 'parseFrame', frame
    if _.isArray(frame) && frame.length
      return callback null, frame...

    callback new Error 'invalid frame, must be in the form of [type, data]'

  setOnlineStatus: (device, online) =>
    message =
      devices: '*',
      topic: 'device-status',
      payload:
        online: online
    @sendMessage device, message

  sendFrame: (type, data) =>
    frame = [type, data]
    debug 'sendFrame', frame
    @socket?.send JSON.stringify frame

  sendError: (message, frame, code) =>
    try
      throw new Error message
    catch e
      debug 'sendError', e.message, e.stack
    @sendFrame 'error', message: message, frame: frame, code: code

  subscribeWithToken: (data) =>
    @authDevice data.uuid, data.token, (error, authedDevice) =>
      debug 'subscribeWithToken', data
      return @sendError error?.message, ['subscribe', data] if error? || !authedDevice?
      subscribeToMessageIO @socketIOClient, authDevice.uuid, data.types || ['broadcast', 'received', 'sent']

  unregisterWithToken: (data) =>
    debug 'unregisterWithToken', data
    @authDevice data.uuid, data.token, (error, authedDevice) =>
      return @sendError error?.message, ['unregister', data] if error? || !authedDevice?
      @unregisterDevice authedDevice, data.uuid
      @sendFrame 'unregistered', uuid: data.uuid

  unsubscribeWithToken: (data) =>
    @authDevice data.uuid, data.token, (error, authedDevice) =>
      debug 'unsubscribeWithToken', data
      return @sendError error?.message, ['unsubscribe', data] if error? || !authedDevice?
      @socketIOClient.emit 'unsubscribe', authedDevice.uuid
      @socketIOClient.emit 'unsubscribe', "#{authedDevice.uuid}_bc"
      @socketIOClient.emit 'unsubscribe', "#{authedDevice.uuid}_sent"

  #socketio event handlers
  onSocketMessage: (data) =>
    @sendFrame 'message', data

module.exports = MeshbluWebsocketHandler
