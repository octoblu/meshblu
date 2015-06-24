debug = require('debug')('meshblu:meshblu-socket.io-handler')

class MeshbluSocketIOHandler
  constructor: (dependencies={}) ->
    @authDevice = dependencies.authDevice ? require './authDevice'
    @updateIfAuthorized = dependencies.updateIfAuthorized ? require './updateIfAuthorized'

  initialize: (@socket) =>
    @socket.on 'identity', (data, callback=->) =>
      @authDevice data.uuid, data.token, (error, device) =>
        return callback [{message: error.message, status: 401}] if error?
        @authedDevice = data
        callback [null, {uuid: device.uuid}]

    @socket.on 'update', @onUpdate

  onUpdate: (data, callback=->) =>
    [query, params] = data
    debug '@authedDevice', @authedDevice
    @authDevice @authedDevice?.uuid, @authedDevice?.token, (error, device) =>
      return callback [{message: 'unauthorized', status: 403}] if error?

      @updateIfAuthorized device, query, params, (error) =>
        return callback [message: error.message, status: 422] if error?
        return callback [null]

module.exports = MeshbluSocketIOHandler
