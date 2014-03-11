var config = require('./../config');
var events = require('./database').collection('events');
var fs = require('fs');
var client = require('./elasticSearch');
// var elasticsearch = require('elasticsearch');

module.exports = function(eventCode, data) {

  function leadingZero(value){
     if(value < 10){
        return "0" + value.toString();
     }
     return value.toString();
  }
  function getMyDateFormat(date) {
    var d = date ? new Date(date) : new Date;
    var dt = [d.getFullYear(), leadingZero(d.getMonth()+1), leadingZero(d.getDate())].join("."),
        tm = [d.getHours(), d.getMinutes(), d.getSeconds()].join(":");
    // return dt + " " + tm;
    return dt;
  }
  function getMyTimeFormat(date) {
    var d = date ? new Date(date) : new Date;
    var dt = [d.getFullYear(), leadingZero(d.getMonth()+1), leadingZero(d.getDate())].join("."),
        tm = [d.getHours(), d.getMinutes(), d.getSeconds()].join(":");
    return dt + " " + tm;
    // return dt;
  }

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

      esId = data.timestamp;
      delete data.timestamp;
      data["@timestamp"] = getMyTimeFormat(esId);

      client.index({
        // index: getMyDateFormat(esId),
        index: "log",
        type: eventCode,
        id: esId,
        body: data
      }, function (error, response) {
        console.log(error);
        console.log(response);
        console.log('logged to elastic search');
      });

      // client.create(data, function (err, resp) {
      //   console.log(err);
      //   console.log(resp);
      //   console.log('logged to elastic search');
      // });

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
