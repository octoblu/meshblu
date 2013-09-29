var events = require('./database').collection('events');

module.exports = function(eventCode, data) {

  // add timestamp if one isn't passed
  if (!data.hasOwnProperty("timestamp")){
    var newTimestamp = new Date().getTime();
    data["timestamp"] = newTimestamp;
  }
  data["eventCode"] = eventCode;

  events.save(data, function(err, saved) {

    if(err || saved.length < 1) {
      console.log('Error logging event: ' + JSON.stringify(data));
    } else {
      console.log('Event Loggged: ' + JSON.stringify(data));      
    }

  });
};
