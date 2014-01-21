var events = require('./database').collection('events');

module.exports = function(uuid, callback) {

  events.find({
    $or: [{fromUuid: uuid}, {uuid:uuid}, { devices: {$in: [uuid, "all", "*"]}}]
  }).limit(10).sort({
    $natural: -1
  }, function(err, eventdata) {

    if(err || eventdata.length < 1) {

      var eventResp = {
        "error": {
          "message": "Events not found",
          "code": 404
        }
      };
      require('./logEvent')(201, eventResp);
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
      require('./logEvent')(201, {"events": eventdata});
      callback({"events": eventdata});
    }
  });
};