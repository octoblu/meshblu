var devices = require('./database').collection('devices');

module.exports = function(uuid, callback) {
  console.log(uuid);
  devices.findOne({
    uuid: uuid
  }, function(err, devicedata) {

    if(err || devicedata === undefined || devicedata.length < 1) {

      var regdata = {
        "error": {
          "message": "Device not found",
          "code": 404
        }
      };
      require('./logEvent')(500, regdata);
      callback(regdata);


    } else {

      // remove token from results object
      delete devicedata.token;
      console.log('Device whoami: ' + JSON.stringify(devicedata));

      require('./logEvent')(500, devicedata);
      callback(devicedata);
    }
  });
};