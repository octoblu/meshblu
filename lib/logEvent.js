var fs            = require('fs');
var moment        = require('moment');
var config        = require('./../config');
var client        = require('./elasticSearch');
var splunkService = require('./splunk');
var RedisSplunk   = require('./redisSplunk');

var events = require('./database').events;

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
  var uuid = eventCode; //Set the Default to EventCode just in case.
  if (data && data.hasOwnProperty("uuid")){ // if the data has a uuid (and it always should)
        uuid = data.uuid; // set the uuid to the actual uuid.
  }

  if(config.log){
    fs.appendFile('./skynet.txt', JSON.stringify(data) + '\r\n', function (err) {
      if (err) {
        throw err;
      }
    });

    if(config.elasticSearch && config.elasticSearch.hosts){
      if(data._id){
        try{
          data._id.toString();
          delete data._id;
        } catch(e){
          console.error(e.message, e.stack);
        }
      }

      var msg = {
        index: "skynet_trans_log",
        type: uuid,
        timestamp: data.timestamp,
        body: data
      };
      client.index(msg, function (error, response) {
        if(error){
          console.error(error, msg);
        }
      });
    }

    // Replaced by Splunk Forwarding Agent
    // RedisSplunk.log(data, function(err){
    //   if(err){
    //     console.error(err);
    //   }
    // });
  }

  events.insert(data, function(err, saved) {
    if(err || saved.length < 1) {
      console.error('Error logging event: ' + JSON.stringify(data));
      console.error('Error: ' + err);
    }
  });
};
