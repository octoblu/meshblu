var data = require('./database').collection('data');

module.exports = function(uuid, callback) {

  data.find({
    uuid:uuid
  }).limit(10).sort({
    $natural: -1
  }, function(err, eventdata) {

    if(err || eventdata.length < 1) {

      var eventResp = {
        "error": {
          "message": "Data not found",
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
      console.log('Data: ' + JSON.stringify(eventdata));
      callback({"data": eventdata});
    }
  });
};
