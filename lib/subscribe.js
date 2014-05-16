var events = require('./database').collection('events');
var moment = require('moment');

module.exports = function(uuid) {

  var newTimestamp = new Date().getTime();
  // var cursor = events.find({
  //   $or: [{fromUuid: uuid}, {uuid:uuid}, { devices: {$in: [uuid, "all", "*"]}}],
  //   timestamp: { $gt : moment(newTimestamp).toISOString() }
  // }, {}, {tailable:true, timeout:false});

  var cursor = events.find({
    $or: [{fromUuid: uuid}, {uuid:uuid}],
    timestamp: { $gt : moment(newTimestamp).toISOString() }
  }, {}, {tailable:true, timeout:false});

  return cursor;

};
