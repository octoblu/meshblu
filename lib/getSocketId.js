var devices = require('./database').collection('devices');

module.exports = function(uuid, callback) {
  console.log('uuid: ' + uuid);
  devices.findOne({
    uuid: {"$regex":uuid,"$options":"i"}
  }, function(err, devicedata) {
    if(err || devicedata.length < 1) {
      console.log('not found');
      callback({});

    } else {

      console.log('socketid: ' + devicedata.socketId);
      callback(devicedata.socketId);
        
    }
  });

}

