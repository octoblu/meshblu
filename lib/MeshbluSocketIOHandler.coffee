debug = require('debug')('meshblu:meshblu-socket.io-handler')
SocketIOThrottler = require './SocketIOThrottler'

class MeshbluSocketIOHandler
  constructor: (dependencies={}) ->
    {@meshbluEventEmitter} = dependencies

    @authDevice = dependencies.authDevice ? require './authDevice'
    @updateIfAuthorized = dependencies.updateIfAuthorized ? require './updateIfAuthorized'

  initialize: (@socket) =>
    @throttler = new SocketIOThrottler @socket

    @socket.on 'identity', @throttler.throttle @onIdentity
    @socket.on 'update', @throttler.throttle @onUpdate

  onIdentity: (data, callback=->) =>
    @authDevice data.uuid, data.token, (error, device) =>
      @log 'identity', error?, request: {uuid: data.uuid}, error: error?.message
      return callback [{message: error.message, status: 401}] if error?
      @authedDevice = data
      callback [null, {uuid: device.uuid}]

  onUpdate: (data, callback=->) =>
    [query, params] = data
    @authDevice @authedDevice?.uuid, @authedDevice?.token, (error, device) =>
      return callback [{message: 'unauthorized', status: 403}] if error?

      @updateIfAuthorized device, query, params, (error) =>
        @log 'update', error?, request: {query: query, params: params}, fromUuid: @authedDevice.uuid, error: error?.message
        return callback [message: error.message, status: 422] if error?
        return callback [null]

  log: (event, didError, data) =>
    @meshbluEventEmitter.log event, didError, data

module.exports = MeshbluSocketIOHandler
