_ = require 'lodash'
config = require '../config'
debug = require('debug')('meshblu:message-io-client')
{EventEmitter2} = require 'eventemitter2'

class MessageIOClient extends EventEmitter2
  constructor: (dependencies={}) ->
    @SocketIOClient = dependencies.SocketIOClient ? require 'socket.io-client'
    @topicMap = {}

  addTopics: (uuid, topics=['*']) =>
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

  close: =>
    @socketIOClient.close()

  defaultTopics: =>

  onMessage: (message) =>
    uuids = message?.devices
    uuids = [uuids] unless _.isArray uuids
    uuids = [message.fromUuid] if _.contains uuids, '*'

    if @topicMatchUuids uuids, message?.topic
      debug 'relay message', message
      @emit 'message', message

  start: =>
    @socketIOClient = @SocketIOClient "ws://localhost:#{config.messageBus.port}", 'force new connection': true
    @socketIOClient.on 'message', @onMessage

    @socketIOClient.on 'data', (message) =>
      debug 'relay message', message
      @emit 'data', message

    @socketIOClient.on 'config', (message) =>
      debug 'relay config', message
      @emit 'config', message

    @socketIOClient.connect()

  subscribe: (uuid, subscriptionTypes, topics) =>
    @addTopics uuid, topics

    subscriptionTypes ?= ['received', 'broadcast', 'sent']

    if _.contains subscriptionTypes, 'received'
      debug 'subscribe', 'received', uuid
      @socketIOClient.emit 'subscribe', uuid

    if _.contains subscriptionTypes, 'broadcast'
      debug 'subscribe', 'broadcast', "#{uuid}_bc"
      @socketIOClient.emit 'subscribe', "#{uuid}_bc"

    if _.contains subscriptionTypes, 'sent'
      debug 'subscribe', 'sent', "#{uuid}_sent"
      @socketIOClient.emit 'subscribe', "#{uuid}_sent"

  unsubscribe: (uuid, subscriptionTypes) =>
    delete @topicMap[uuid]

    subscriptionTypes ?= ['received', 'broadcast', 'sent']

    if _.contains subscriptionTypes, 'received'
      debug 'unsubscribe', 'received', uuid
      @socketIOClient.emit 'unsubscribe', uuid

    if _.contains subscriptionTypes, 'broadcast'
      debug 'unsubscribe', 'broadcast', "#{uuid}_bc"
      @socketIOClient.emit 'unsubscribe', "#{uuid}_bc"

    if _.contains subscriptionTypes, 'sent'
      debug 'unsubscribe', 'sent', "#{uuid}_sent"
      @socketIOClient.emit 'unsubscribe', "#{uuid}_sent"

  topicMatchUuids: (uuids, topic) =>
    _.any uuids, (uuid) =>
      @topicMatch uuid, topic

  topicMatch: (uuid, topic) =>
    @addTopics uuid unless @topicMap[uuid]?

    debug 'topicMatch', @topicMap[uuid], topic
    return false if _.any @topicMap[uuid].skips, (re) => re.test topic
    _.any @topicMap[uuid].names, (re) => re.test topic

module.exports = MessageIOClient
