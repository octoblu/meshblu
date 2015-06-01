_ = require 'lodash'
debug = require('debug')('meshblu:subscribeToMessageIO')

module.exports = (socketIOClient, uuid, subscriptionTypes) ->
  if _.contains subscriptionTypes, 'received'
    debug 'subscribeToMessageIO', 'received', uuid
    socketIOClient.emit 'subscribe', uuid

  if _.contains subscriptionTypes, 'broadcast'
    debug 'subscribeToMessageIO', 'broadcast', uuid + '_bc'
    socketIOClient.emit 'subscribe', uuid + '_bc'

  if _.contains subscriptionTypes, 'sent'
    debug 'subscribeToMessageIO', 'sent', uuid + '_sent'
    socketIOClient.emit 'subscribe', uuid + '_sent'
