var config = require('./../config');

if(config.splunk){
  var splunk = require('splunk-sdk');
  var splunkService = new splunkjs.Service({
    host: config.splunk.host,
    port: config.splunk.port,
    scheme: config.splunk.protocol,
    username: config.splunk.user,
    password: config.splunk.password
  });
  var myindexes = splunkService.indexes();
  myindexes.fetch(function(err, myindexes) {
	config.splunk.indexObj = myindexes.item(config.splunk.index);
  });
  module.exports = splunkService;
}
