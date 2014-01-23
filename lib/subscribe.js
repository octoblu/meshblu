var events = require('./database').collection('events');

module.exports = function(uuid) {

  var newTimestamp = new Date().getTime();
  var cursor = events.find({
    $or: [{fromUuid: uuid}, {uuid:uuid}, { devices: {$in: [uuid, "all", "*"]}}],
    timestamp: { $gt : newTimestamp }
  }, {}, {tailable:true, timeout:false});

  return cursor;

};