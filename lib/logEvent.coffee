_ = require 'lodash'

module.exports = (eventCode, data, dependencies={}) ->
  config = dependencies.config || require '../config'
  moment = dependencies.moment || require 'moment'

  data = _.cloneDeep data || {}
  data.eventCode = eventCode || 0
  data.timestamp ?= moment().toISOString()

  if data.payload && !_.isPlainObject data.payload
    data.payload = message: data.payload

  if config.eventLoggers?
    config.eventLoggers.console.log 'info', data if config.eventLoggers.console
    config.eventLoggers.file.log 'info', data if config.eventLoggers.file
    config.eventLoggers.elasticSearch.log eventCode, _.omit(data, 'eventCode') if config.eventLoggers.elasticSearch
    config.eventLoggers.splunk.log 'info', data if config.eventLoggers.splunk
