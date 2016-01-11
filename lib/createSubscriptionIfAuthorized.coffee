_ = require 'lodash'
SimpleAuth = require './simpleAuth'

createSubscriptionIfAuthorized = (authedDevice, params, callback=_.noop, dependencies={}) ->
  database = dependencies.database ? require './database'
  getDevice = dependencies.getDevice ? require './getDevice'

  unless _.contains ['broadcast', 'config', 'received', 'sent'], params.type
    return callback new Error 'Type must be one of ["broadcast", "config", "received", "sent"]'

  getDevice params.subscriberUuid, (error, toDevice) =>
    return callback error if error?

    simpleAuth = new SimpleAuth()
    simpleAuth.canConfigure authedDevice, toDevice, (error, canConfigure) =>
      return callback error if error?
      return callback new Error('Insufficient permissions to subscribe on behalf of that device') unless canConfigure

      subscription = {subscriberUuid: params.subscriberUuid, emitterUuid: params.emitterUuid, type: params.type}
      database.subscriptions.update subscription, subscription, upsert: true, callback

module.exports = createSubscriptionIfAuthorized
