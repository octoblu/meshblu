var devices = require('./database').collection('devices');

module.exports = function(uuid, params, callback) {

  var newTimestamp = new Date().getTime();
  var regdata;

  devices.remove({
    uuid: {"$regex":uuid,"$options":"i"}, token: params.token
  }, function(err, devicedata) {

    if(err || devicedata === 0) {

      regdata = {
        "error": {
          "message": "Device not found or token not valid",
          "code": 404
        }
      };
      require('./logEvent')(402, regdata);
      callback(regdata);


    } else {

      regdata = {
        uuid: uuid,
        timestamp: newTimestamp
      };
      console.log('Device unregistered: ' + JSON.stringify(regdata));

      require('./logEvent')(402, regdata);
      callback(regdata);

    }

  });

};