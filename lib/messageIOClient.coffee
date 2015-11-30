_ = require 'lodash'
async = require 'async'
config = require '../config'
debug = require('debug')('meshblu:message-io-client')
{createClient} = require './redis'
{EventEmitter2} = require 'eventemitter2'
Subscriber = require './Subscriber'

class MessageIOClient extends EventEmitter2
  @DEFAULT_SUBSCRIPTION_TYPES: []

  constructor: ({namespace}={}, dependencies={}) ->
    namespace ?= 'meshblu'
    @topicMap = {}
    @subscriber = new Subscriber namespace: namespace
    @subscriber.on 'message', @_onMessage

  close: =>
    @subscriber.close()

  subscribe: (uuid, subscriptionTypes, topics, callback) =>
    subscriptionTypes ?= MessageIOClient.DEFAULT_SUBSCRIPTION_TYPES
    @_addTopics uuid, topics
    async.each subscriptionTypes, (type, done) =>
      @subscriber.subscribe type, uuid, done
    , callback

  unsubscribe: (uuid, subscriptionTypes, callback) =>
    subscriptionTypes ?= MessageIOClient.DEFAULT_SUBSCRIPTION_TYPES
    delete @topicMap[uuid]

    async.each subscriptionTypes, (type, done) =>
      @subscriber.unsubscribe type, uuid, done
    , callback

  _addTopics: (uuid, topics=['*']) =>
    topics = [topics] unless _.isArray topics
    [skips, names] = _.partition topics, (topic) => _.startsWith topic, '-'
    names = ['*'] if _.isEmpty names
    map = {}

    map.names = _.map names, (topic) =>
      topic = topic.replace(/\*/g, '.*?')
      new RegExp "^#{topic}$"

    map.skips = _.map skips, (topic) =>
      topic = topic.replace(/\*/g, '.*?').replace(/^-/, '')
      new RegExp "^#{topic}$"

    @topicMap[uuid] = map

  _defaultTopics: =>

  _onMessage: (channel, message) =>
    if _.contains channel, ':config:'
      @emit 'config', message
      return

    if _.contains channel, ':data:'
      @emit 'data', message
      return

    uuids = message?.devices
    uuids = [uuids] unless _.isArray uuids
    uuids = [message.fromUuid] if _.contains uuids, '*'

    if @_topicMatchUuids uuids, message?.topic
      debug 'relay message', message
      @emit 'message', message

  _topicMatchUuids: (uuids, topic) =>
    _.any uuids, (uuid) =>
      @_topicMatch uuid, topic

  _topicMatch: (uuid, topic) =>
    @_addTopics uuid unless @topicMap[uuid]?

    debug 'topicMatch', @topicMap[uuid], topic
    return false if _.any @topicMap[uuid].skips, (re) => re.test topic
    _.any @topicMap[uuid].names, (re) => re.test topic

module.exports = MessageIOClient
