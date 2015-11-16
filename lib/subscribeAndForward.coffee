_ = require 'lodash'
authDevice = require './authDevice'
getDevice = require './getDevice'
config = require '../config'
MessageIOClient = require './messageIOClient'
{Readable} = require 'stream'
securityImpl = require './getSecurityImpl'
debug = require('debug')('meshblu:subscribeAndForward')

subscribeAndForwardWithToken = (response, uuid, token, requestedSubscriptionTypes, payloadOnly, topics) ->
  authDevice uuid, token, (error, authedDevice) ->
    messageIOClient = connectMessageIO(response, payloadOnly)
    messageIOClient.subscribe uuid, requestedSubscriptionTypes, topics

connectMessageIO = (response, payloadOnly=false) ->
  messageIOClient = new MessageIOClient()
  readStream = new Readable
  readStream._read = _.noop
  readStream.pipe response

  messageIOClient.on 'message', (message) ->
    debug 'onMessage', message
    if payloadOnly
      message = message?.payload

    readStream.push JSON.stringify(message) + '\n'

  response.on 'close', ->
    messageIOClient.close()

  return messageIOClient

subscribeAndForward = (askingDevice, response, uuid, token, requestedSubscriptionTypes, payloadOnly, topics) ->
  uuid = uuid || askingDevice.uuid
  if token
    return subscribeAndForwardWithToken(response, uuid, token, requestedSubscriptionTypes, payloadOnly, topics)
  newSubscriptionTypes = []
  getDevice uuid, (error, subscribedDevice) ->
    if error
      return response.status(401).send(error: 'unauthorized')
    securityImpl.canReceive askingDevice, subscribedDevice, (error, permission) ->
      if error
        return response.status(401).send(error: 'unauthorized')
      if !permission && subscribedDevice.owner != askingDevice.uuid
        return response.status(401).send(error: 'unauthorized')

      authorizedSubscriptionTypes = []
      authorizedSubscriptionTypes.push 'broadcast'

      securityImpl.canReceiveAs askingDevice, subscribedDevice, (error, permission) ->
        if error
          return response.status(401).send(error: 'unauthorized')

        if permission
          authorizedSubscriptionTypes.push 'broadcast'
          authorizedSubscriptionTypes.push 'received'
          authorizedSubscriptionTypes.push 'sent'
          authorizedSubscriptionTypes.push 'config'
          authorizedSubscriptionTypes.push 'data'

        requestedSubscriptionTypes ?= authorizedSubscriptionTypes
        requestedSubscriptionTypes = _.union requestedSubscriptionTypes, ['config', 'data']
        subscriptionTypes = _.intersection requestedSubscriptionTypes, authorizedSubscriptionTypes

        messageIOClient = connectMessageIO(response, payloadOnly)
        messageIOClient.subscribe uuid, subscriptionTypes, topics

module.exports = subscribeAndForward
