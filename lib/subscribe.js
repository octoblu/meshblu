var events = require('./database').collection('events');
var JSONStream = require('JSONStream');

module.exports = function(uuid, callback) {
  // db.mycollection.find({}).pipe(JSONStream.stringify()).pipe(process.stdout);
  console.log('subscripe api');
  console.log(uuid);

  var newTimestamp = new Date().getTime();
  // events.find({
  //   $or: [{fromUuid: uuid}, {uuid:uuid}, { devices: {$in: [uuid, "all", "*"]}}],
  //   timestamp: { $gt : newTimestamp }
  // }).pipe(JSONStream.stringify()).pipe(process.stdout);

  var cursor = events.find({
    $or: [{fromUuid: uuid}, {uuid:uuid}, { devices: {$in: [uuid, "all", "*"]}}],
    timestamp: { $gt : newTimestamp }
  }, {}, {tailable:true, timeout:false});

  // since all cursors are streams we can just listen for data
  cursor.on('data', function(doc) {
      console.log('new document', doc);
      callback({"events": doc});
  });

};