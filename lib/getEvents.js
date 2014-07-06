var config = require('./../config');

var events = require('./database').events;

module.exports = function(uuid, callback) {

  function processResults(err, eventdata){
    if(err || eventdata.length < 1) {

      var eventResp = {
        "error": {
          "message": "Events not found",
          "code": 404
        }
      };
      // require('./logEvent')(201, eventResp);
      callback(eventResp);

    } else {

      // remove tokens from results object
      for (var i=0;i<eventdata.length;i++)
      {
        delete eventdata[i].token;
        eventdata[i].id = eventdata[i]._id;
        delete eventdata[i]._id;
      }
      console.log('Events: ' + JSON.stringify(eventdata));
      callback({"events": eventdata});
    }

  }

  if(config.mongo){
    events.find({
      $or: [{fromUuid: uuid}, {uuid:uuid}, { devices: {$in: [uuid, "all", "*"]}}]
    }).limit(10).sort({ $natural: -1 }, function(err, eventdata) {
      console.log(err);
      console.log(eventdata);
      processResults(err, eventdata);
    });
  } else {
    events.find({
      $or: [{fromUuid: uuid}, {uuid:uuid}, { devices: {$in: [uuid, "all", "*"]}}]
    }).limit(10).sort({ timestamp: -1 }).exec(function(err, eventdata) {
      processResults(err, eventdata);
    });
  }

};
