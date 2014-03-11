var config = require('./../config');
var events = require('./database').collection('events');
var fs = require('fs');
var client = require('./elasticSearch');
// var elasticsearch = require('elasticsearch');

module.exports = function(eventCode, data) {
  // add timestamp if one isn't passed
  if (data && !data.hasOwnProperty("timestamp")){
    var newTimestamp = new Date().getTime();
    data.timestamp = newTimestamp;
  }

  if(eventCode === undefined){
    eventCode = 0;
  }

  data.eventCode = eventCode;

  if(config.log){
    fs.appendFile('./skynet.txt', JSON.stringify(data) + '\r\n', function (err) {
      if (err) {
        throw err;
      }

      console.log('Log file udpated');
    });

    if(config.elasticSearch){
      // var elasticsearch = require('elasticsearch');
      // var client = new elasticsearch.Client({
      //   host: config.elasticSearch.host + ':' + config.elasticSearch.port
      // });
      client.create(data, function (err, resp) {
        console.log('logged to elastic search');
      });

    }

  }

  events.save(data, function(err, saved) {
    if(err || saved.length < 1) {
      console.log('Error logging event: ' + JSON.stringify(data));
      console.log('Error: ' + err);
    } else {
      console.log('Event Loggged: ' + JSON.stringify(data));
    }

  });
};
