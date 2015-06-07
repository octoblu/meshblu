_ = require 'lodash'
debug = require('debug')('meshblu:subscribeToMessageIO')

module.exports = (socketIOClient, uuid, subscriptionTypes) ->
  if _.contains subscriptionTypes, 'received'
    debug socketIOClient.id, 'subscribeToMessageIO', 'received', uuid
    socketIOClient.emit 'subscribe', uuid, socketIOClient.id

  if _.contains subscriptionTypes, 'broadcast'
    debug socketIOClient.id, 'subscribeToMessageIO', 'broadcast', uuid + '_bc'
    socketIOClient.emit 'subscribe', uuid + '_bc', socketIOClient.id

  if _.contains subscriptionTypes, 'sent'
    debug socketIOClient.id, 'subscribeToMessageIO', 'sent', uuid + '_sent'
    socketIOClient.emit 'subscribe', uuid + '_sent', socketIOClient.id
