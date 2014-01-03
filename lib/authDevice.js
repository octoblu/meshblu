var devices = require('./database').collection('devices');

module.exports = function(uuid, token, callback) {
  devices.findOne({
    uuid: {"$regex":uuid,"$options":"i"}, token: token
  }, function(err, devicedata) {
    if(err || !devicedata || devicedata.length < 1) {
      // console.log('uuid not found');
      callback({'authenticate': false});

    } else {
      // console.log('uuid and token authenticated');
      callback({'authenticate': true});

    }
  });

};

