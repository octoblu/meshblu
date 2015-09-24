SubscriptionGetter = require './SubscriptionGetter'

module.exports = (emitterUuid, type, callback) ->
  subscriptionGetter = new SubscriptionGetter emitterUuid: emitterUuid, type: type
  subscriptionGetter.get callback
