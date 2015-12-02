_ = require 'lodash'
config = require '../config'
debug = require('debug')('meshblu:meshblu-websocket-handler')
{EventEmitter} = require 'events'
uuid = require 'node-uuid'

class MeshbluWebsocketHandler extends EventEmitter
  constructor: (dependencies={})->
    @authDevice = dependencies.authDevice ? require './authDevice'
    @MessageIOClient = dependencies.MessageIOClient ? require './messageIOClient'
    @getSystemStatus = dependencies.getSystemStatus ? require './getSystemStatus'
    @securityImpl = dependencies.securityImpl ? require './getSecurityImpl'
    @getDevice = dependencies.getDevice ? require './getDevice'
    @getDeviceIfAuthorized = dependencies.getDeviceIfAuthorized ? require './getDeviceIfAuthorized'
    @getDevices = dependencies.getDevices ? require './getDevices'
    @registerDevice = dependencies.registerDevice ? require './register'
    @unregisterDevice = dependencies.unregisterDevice ? require './unregister'
    @sendMessage = dependencies.sendMessage
    @meshbluEventEmitter = dependencies.meshbluEventEmitter
    @updateIfAuthorized = dependencies.updateIfAuthorized ? require './updateIfAuthorized'
    @throttles = dependencies.throttles ? require './getThrottles'

  initialize: (@socket, request) =>
    @socket.id = uuid.v4()
    @headers = request?.headers

    @socket.on 'open', @onOpen
    @socket.on 'close', @onClose
    @socket.on 'message', @onMessage

    @addListeners()

  # event handlers
  onOpen: (event) =>
    debug 'on.open'
    @messageIOClient = new @MessageIOClient()
    @messageIOClient.on 'message', @onSocketMessage
    @messageIOClient.on 'config', @onSocketConfig
    @messageIOClient.on 'data', @onSocketData

  onClose: (event) =>
    debug 'on.close'
    @authDevice @uuid, @token, (error, device) =>
      return if error?
      @setOnlineStatus device, false
      @messageIOClient.close()

  onMessage: (event) =>
    debug 'onMessage', event.data
    @parseFrame event.data, (error, type, data) =>
      return @sendError error.message, event.data if error?

      @rateLimit @socket.id, type, (error) =>
        return @closeWithError error, [type,data], 429 if error?
        return @emit type, data if type == 'identity'
        return @emit type, data if type == 'register'

        @authDevice @uuid, @token, (error, authedDevice)=>
          return @sendError 'unauthorized', [type, data], 401 if error?
          @authedDevice = authedDevice

          @emit type, data

  closeWithError: (error, frame, code) =>
    @sendError error.message, frame, 429
    @socket.close 429, error.message

  # message handlers
  device: (data) =>
    debug 'device', data
    @getDeviceIfAuthorized @authedDevice, data, (error, foundDevice) =>
      @log 'devices', error?, request: data, error: error?.message, fromUuid: @authedDevice.uuid
      return @sendError error.message, ['device', data] if error?
      @sendFrame 'device', foundDevice

  devices: (data) =>
    debug 'devices', data
    @getDevices @authedDevice, data, null, (foundDevices) =>
      @log 'devices', foundDevices.error?, request: data, error: foundDevices.error?.message, fromUuid: @authedDevice.uuid
      @sendFrame 'devices', foundDevices

  identity: (data) =>
    data ?= {}
    {@uuid, @token} = data
    @authDevice @uuid, @token, (error, device) =>
      @log 'identity', error?, request: {uuid: @uuid}, error: error?.message, fromUuid: @uuid
      return @sendFrame 'notReady', message: 'unauthorized', status: 401 if error?
      @sendFrame 'ready', uuid: @uuid, token: @token, status: 200
      @setOnlineStatus device, true
      @messageIOClient.subscribe @uuid, ['received', 'config', 'data']

  message: (data) =>
    debug 'message', data
    @log 'message', null, request: data, fromUuid: @authedDevice.uuid
    @sendMessage @authedDevice, data

  mydevices: (data={}) =>
    data.owner = @uuid
    @getDevices @authedDevice, data, null, (result) =>
      {error,devices} = result

      error = null if error?.message == "Devices not found"
      devices ?= data.devices

      @log 'devices', error?, request: data , fromUuid: @uuid, error: error?.message

      return @sendError error.message, ['mydevices', data] if error?
      @sendFrame 'mydevices', devices

  register: (data) =>
    debug 'register', data
    @registerDevice data, (error, device) =>
      @log 'register', error?, request: data, fromUuid: @uuid, error: error?.message
      return @sendError error.message, ['register', data] if error?
      @sendFrame 'registered', device

  status: =>
    @getSystemStatus (status) =>
      @sendFrame 'status', status

  subscribe: (data) =>
    @subscribeIfAuthorized data, (error) =>
      @log 'subscribe', error?, request: data, fromUuid: @authedDevice.uuid, error: error?.message
      return @sendError (error.message ? error), ['subscribe', data] if error?

  unsubscribe: (data) =>
    @log 'unsubscribe', null, request: data, fromUuid: @authedDevice.uuid
    subscriptionTypes = data.types ? ['sent', 'received', 'broadcast']
    @messageIOClient.unsubscribe data.uuid, subscriptionTypes

  unregister: (data) =>
    debug 'unregister', data

    @unregisterDevice @authedDevice, data.uuid, null, null, (error) =>
      @log 'unregister', error?, request: data, fromUuid: @uuid, error: (error?.message ? error ? undefined)
      return @sendError (error.message ? error), ['unregister', data] if error?
      @sendFrame 'unregistered', uuid: data.uuid

  update: (data) =>
    [query,params] = data
    @updateIfAuthorized @authedDevice, query, params, (error) =>
      @log 'update', error?, request: {query: query, params: params}, fromUuid: @uuid, error: error?.message
      return @sendError error.message, ['update', data] if error?
      @sendFrame 'updated', uuid: query.uuid

  whoami: =>
    @log 'devices', null, request: {uuid: @uuid}, fromUuid: @uuid
    @sendFrame 'whoami', @authedDevice

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

  log: (event, didError, data) =>
    @meshbluEventEmitter.log event, didError, data

  parseFrame: (frame, callback=->) =>
    try frame = JSON.parse frame
    debug 'parseFrame', frame
    if _.isArray(frame) && frame.length
      return callback null, frame...

    callback new Error 'invalid frame, must be in the form of [type, data]'

  rateLimit: (id, type, callback=->) =>
    throttle = @throttles[type] ? @throttles.query

    callback() unless throttle?
    throttle.rateLimit id, (error, isLimited) =>
      debug 'rateLimit', id, type, isLimited

      return callback error if error?
      return callback new Error('request exceeds rate limit') if isLimited
      callback()

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
    @sendFrame 'error', message: message, frame: frame, status: code

  subscribeIfAuthorized: (data, callback=->) =>
    @getDevice data.uuid, (error, subscribedDevice) =>
      return callback error if error?
      @securityImpl.canReceive @authedDevice, subscribedDevice, (error, permission) =>
        return callback error if error?

        requestedSubscriptionTypes = data.types ? ['broadcast', 'received', 'sent']

        authorizedSubscriptionTypes = []
        authorizedSubscriptionTypes.push 'broadcast' if permission

        @securityImpl.canReceiveAs @authedDevice, subscribedDevice, (error, permission) =>
          return callback error if error?

          if permission
            authorizedSubscriptionTypes.push 'broadcast'
            authorizedSubscriptionTypes.push 'received'
            authorizedSubscriptionTypes.push 'sent'
            authorizedSubscriptionTypes.push 'config'
            authorizedSubscriptionTypes.push 'data'

          requestedSubscriptionTypes = requestedSubscriptionTypes ? authorizedSubscriptionTypes
          requestedSubscriptionTypes = _.union requestedSubscriptionTypes, ['config', 'data']
          subscriptionTypes = _.intersection(requestedSubscriptionTypes, authorizedSubscriptionTypes)

          @messageIOClient.subscribe subscribedDevice.uuid, subscriptionTypes
          callback()

  #socketio event handlers
  onSocketMessage: (data) =>
    @sendFrame 'message', data

  onSocketConfig: (data) =>
    @sendFrame 'config', data

  onSocketData: (data) =>
    @sendFrame 'data', data

module.exports = MeshbluWebsocketHandler
