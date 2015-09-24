_ = require 'lodash'
SimpleAuth = require './simpleAuth'

createSubscriptionIfAuthorized = (authedDevice, params, callback=_.noop, dependencies={}) ->
  database = dependencies.database ? require './database'
  getDevice = dependencies.getDevice ? require './getDevice'

  unless _.contains ['event', 'broadcast'], params.type
    return callback new Error 'Type must be one of ["event", "broadcast"]'

  getDevice params.uuid, (error, toDevice) =>
    return callback error if error?

    simpleAuth = new SimpleAuth()
    simpleAuth.canConfigure authedDevice, toDevice, (error, canConfigure) =>
      return callback error if error?
      return callback new Error('Insufficient permissions to subscribe on behalf of that device') unless canConfigure

      subscription = {subscriberUuid: params.uuid, emitterUuid: params.targetUuid, type: params.type}
      database.subscriptions.update subscription, subscription, upsert: true, callback

module.exports = createSubscriptionIfAuthorized
