var config = require('./../config');

if(config.elasticSearch){
  var elasticsearch = require('elasticsearch');
  var client = new elasticsearch.Client({
    hosts: config.elasticSearch.hosts
  });
  module.exports = client;
}
