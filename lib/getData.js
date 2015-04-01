var moment = require('moment');
var config = require('./../config');

var data = require('./database').data;
var events = require('./database').events;
var logEvent = require('./logEvent');


module.exports = function(req, callback) {

  var uuid = req.params.uuid;
  var start = req.query.start; // time to start from
  var finish = req.query.finish; // time to end
  var limit = req.query.limit; // 0 bypasses the limit
  var stream = req.query.stream;

  var query = {
    'uuid':uuid
  }

  // set a default limit
  limit = parseInt(limit || 10);

  if (start) {
    start = moment(start).toISOString();
    query['timestamp'] = {"$gte": start};
  }

  if (finish) {
    finish = moment(finish).toISOString();
    query['timestamp'] = query['timestamp'] || {};
    query['timestamp']['$lte'] = finish;
  }

  if(stream){

    query["eventCode"] = 700; // data api eventcode

    var newTimestamp = new Date().getTime();
    query["timestamp"] = { '$gte' : moment(newTimestamp).toISOString()}
    logEvent(701, query);
    var cursor = events.find(query, {}, {tailable:true, timeout:false});
    return cursor;

  } else {
    if(config.mongo && config.mongo.databaseUrl) {
      data.find(query, {_id: false}).limit(limit).sort({ _id: -1 }, function(err, eventdata) {
        if(err) {
          return callback(err);
        }

        logEvent(701, query);
        callback({"data": eventdata});
      });
    } else {
      data.find(query).limit(limit).sort({ timestamp: -1 }).exec(function(err, eventdata) {
        if(err) {
          return callback(err);
        }

        logEvent(701, query);
        callback({"data": eventdata});
      });
    }
  }

};
