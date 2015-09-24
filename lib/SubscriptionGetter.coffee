_          = require 'lodash'
async      = require 'async'
debug      = require('debug')('meshblu:SubscriptionGetter')
SimpleAuth = require './simpleAuth'

class SubscriptionGetter
  constructor: (options, dependencies={}) ->
    {@emitterUuid, @type} = options
    {@subscriptions, @getDevice, @simpleAuth} = dependencies

    @subscriptions ?= require('./database').subscriptions
    @getDevice     ?= require './getDevice'
    @simpleAuth    ?= new SimpleAuth

  get: (callback) =>
    query = emitterUuid: @emitterUuid, type: @type
    @getDevice @emitterUuid, (error, emitterDevice) =>
      return callback error if error?

      @subscriptions.find query, (error, subscriptions) =>
        return callback error if error?
        uuids = _.pluck subscriptions, 'subscriberUuid'

        @_getDevices uuids, (error, devices) =>
          return callback error if error?

          @_filterCanReceive emitterDevice, devices, (error, devices) =>
            return callback error if error?
            callback null, _.pluck devices, 'uuid'

  _getDevices: (uuids, callback) =>
    async.mapSeries uuids, (uuid, next) =>
      @getDevice uuid, next
    , callback

  _filterCanReceive: (emitterDevice, devices, callback) =>
    async.mapSeries devices, (toDevice, next) =>
      @simpleAuth.canReceive toDevice, emitterDevice, (error, canReceive) =>
        return next error if error
        return next null, toDevice if canReceive
        next()
    , (error, devices) =>
      callback error, _.compact(devices)


module.exports = SubscriptionGetter
