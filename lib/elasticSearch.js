var config = require('./../config');
var _ = require('lodash');

if(config.elasticSearch && !_.isEmpty(config.elasticSearch.hosts)){
  var elasticsearch = require('elasticsearch');
  var client = new elasticsearch.Client({
    hosts: config.elasticSearch.hosts
  });
  module.exports = client;
}
