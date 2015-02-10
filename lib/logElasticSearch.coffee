class LogElasticSearch
  constructor: (options, dependencies={}) ->
    ElasticSearch = dependencies.ElasticSearch ? require('elasticsearch').Client
    @console = dependencies.console ? console
    @elasticsearch = new ElasticSearch options

  log: (eventCode, body) =>
    @elasticsearch.create index: "meshblu_events_#{eventCode}", type: 'event', body: body, (error) =>
      @console.error error if error?

module.exports = LogElasticSearch
