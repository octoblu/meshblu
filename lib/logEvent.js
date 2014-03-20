var config = require('./../config');
var events = require('./database').collection('events');
var fs = require('fs');
var client = require('./elasticSearch');
// var elasticsearch = require('elasticsearch');
var moment = require('moment');

module.exports = function(eventCode, data) {

  // add timestamp if one isn't passed
  if (data && !data.hasOwnProperty("timestamp")){
    var newTimestamp = new Date().getTime();
    data.timestamp = newTimestamp;
  }
  // moment().toISOString()
  data.timestamp = moment(data.timestamp).toISOString()


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

      try{
        data._id.toString();
        delete data._id;
      } catch(e){
        console.log(e);
      }

      client.index({
        // index: getMyDateFormat(esId),
        index: "log",
        type: eventCode,
        // id: esId,
        timestamp: data.timestamp,
        body: data
      }, function (error, response) {
        if(error){
          console.log(error);
          console.log(data);
        } else {
          console.log(response);
        }

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
