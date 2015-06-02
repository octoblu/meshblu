_ = require 'lodash'
authDevice = require './authDevice'
getDevice = require './getDevice'
config = require '../config'
SocketIOClient = require 'socket.io-client'
{Readable} = require 'stream'
subscribeToMessageIO = require './subscribeToMessageIO'
securityImpl = require './getSecurityImpl'
debug = require('debug')('meshblu:subscribeAndForward')

subscribeAndForwardWithToken = (response, uuid, token, subscriptionTypes) ->
  authDevice uuid, token, (error, authedDevice) ->
    socketIOClient = connectMessageIO(response)
    subscribeToMessageIO socketIOClient, uuid, subscriptionTypes or [
      'received'
      'broadcast'
      'sent'
    ]

connectMessageIO = (response) ->
  socketIOClient = SocketIOClient('ws://localhost:' + config.messageBus.port)
  readStream = new Readable
  readStream._read = _.noop
  readStream.pipe response
  socketIOClient.on 'message', (message) ->
    debug 'onMessage', message
    readStream.push JSON.stringify(message) + '\n'

  return socketIOClient

subscribeAndForward = (askingDevice, response, uuid, token, subscriptionTypes) ->
  uuid = uuid or askingDevice.uuid
  if token
    return subscribeAndForwardWithToken(response, uuid, token, subscriptionTypes)
  newSubscriptionTypes = []
  getDevice uuid, (error, subscribedDevice) ->
    if error
      return response.status(401).send(error: 'unauthorized')
    securityImpl.canReceive askingDevice, subscribedDevice, (error, permission) ->
      if error
        return response.status(401).send(error: 'unauthorized')
      if !permission && subscribedDevice.owner != askingDevice.uuid
        return response.status(401).send(error: 'unauthorized')
      newSubscriptionTypes.push 'broadcast'
      if subscribedDevice.owner and subscribedDevice.owner == askingDevice.uuid or subscribedDevice.uuid == askingDevice.uuid
        newSubscriptionTypes.push 'received'
        newSubscriptionTypes.push 'sent'
      socketIOClient = connectMessageIO(response)
      subscribeToMessageIO socketIOClient, uuid, subscriptionTypes or newSubscriptionTypes

module.exports = subscribeAndForward
