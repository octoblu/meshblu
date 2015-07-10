_ = require 'lodash'
SimpleAuth = require './simpleAuth'

deleteSubscriptionIfAuthorized = (authedDevice, params, callback=_.noop, dependencies={}) ->
  database = dependencies.database ? require './database'
  getDevice = dependencies.getDevice ? require './getDevice'

  getDevice params.uuid, (error, toDevice) =>
    return callback error if error?

    simpleAuth = new SimpleAuth()
    simpleAuth.canConfigure authedDevice, toDevice, (error, canConfigure) =>
      return callback error if error?
      return callback new Error('Insufficient permissions to remove subscription on behalf of that device') unless canConfigure

      subscription = {subscriberUuid: params.uuid, emitterUuid: params.targetUuid, type: params.type}
      database.subscriptions.remove subscription, multi: true, callback

module.exports = deleteSubscriptionIfAuthorized
