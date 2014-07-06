var config = require('./../config');
var fs = require('fs');
var client = require('./elasticSearch');
var moment = require('moment');

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

      console.log('Log file updated');
    });

    if(config.elasticSearch){
      if(data._id){
        try{
          data._id.toString();
          delete data._id;
        } catch(e){
          console.log(e);
        }
      }

      client.index({
        // index: "log",
        // type: eventCode,
        index: "skynet_trans_log",
        type: uuid,        
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

  events.insert(data, function(err, saved) {
    if(err || saved.length < 1) {
      console.log('Error logging event: ' + JSON.stringify(data));
      console.log('Error: ' + err);
    } else {
      console.log('Event Loggged: ' + JSON.stringify(data));
    }

  });
};
