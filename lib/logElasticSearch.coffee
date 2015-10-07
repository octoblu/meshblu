class LogElasticSearch
  constructor: (options, dependencies={}) ->
    ElasticSearch = dependencies.ElasticSearch ? require('elasticsearch').Client
    {@logError} = dependencies
    @logError ?= require './logError'
    @elasticsearch = new ElasticSearch options

  log: (eventCode, body) =>
    @elasticsearch.create index: "meshblu_events_#{eventCode}", type: 'event', body: body, (error) =>
      return unless error?

      try
        throw error
      catch error
        error.createParams = index: "meshblu_events_#{eventCode}", type: 'event', body: body
        @logError error

module.exports = LogElasticSearch
