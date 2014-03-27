var data = require('./database').collection('data');

module.exports = function(req, callback) {

  var uuid = req.params.uuid;
  var start = req.query.start; // time to start from
  var finish = req.query.finish; // time to end
  var limit = req.query.limit; // 0 bypasses the limit

  var query = {
    'uuid':uuid
  }

  // set a default limit
  if (!limit) {
    limit = 10;
  } else {
    limit = parseInt(limit);
  }

  if (start && finish) {
    start = new Date(start);
    finish = new Date(finish);
    query['timestamp'] = {"$gte": start, "$lt": finish}
  }

  data.find(query).limit(limit).sort({
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
