_ = require 'lodash'
SimpleAuth = require './simpleAuth'

createSubscriptionIfAuthorized = (authedDevice, params, callback=_.noop, dependencies={}) ->
  database = dependencies.database ? require './database'
  getDevice = dependencies.getDevice ? require './getDevice'

  getDevice params.uuid, (error, toDevice) =>
    return callback error if error?
    console.log authedDevice, toDevice

    simpleAuth = new SimpleAuth()
    simpleAuth.canConfigure authedDevice, toDevice, (error, canConfigure) =>
      return callback error if error?
      return callback new Error('Insufficient permissions to subscribe on behalf of that device') unless canConfigure

      subscription = {subscriberUuid: params.uuid, emitterUuid: params.targetUuid, type: params.type}
      database.subscriptions.insert subscription, callback

module.exports = createSubscriptionIfAuthorized
