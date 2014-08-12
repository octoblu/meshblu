var config = require('./../config');

if(config.splunk && config.splunk.indexObj){
  var splunk = require('splunk-sdk');
  var splunkService = new splunk.Service({
    host: config.splunk.host,
    port: config.splunk.port,
    scheme: config.splunk.protocol,
    username: config.splunk.user,
    password: config.splunk.password
  });
  var myindexes = splunkService.indexes();
  myindexes.fetch(function(err, myindexes) {
    if(myindexes){
  	 config.splunk.indexObj = myindexes.item(config.splunk.index);
    }
  });

  module.exports = splunkService;
}
