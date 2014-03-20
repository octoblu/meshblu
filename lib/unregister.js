var devices = require('./database').collection('devices');

module.exports = function(uuid, params, callback) {

  var regdata;

  devices.remove({
    uuid: uuid, token: params.token
  }, function(err, devicedata) {

    if(err || devicedata === 0) {

      regdata = {
        "error": {
          "message": "Device not found or token not valid",
          "code": 404
        }
      };
      callback(regdata);


    } else {

      regdata = {
        uuid: uuid
      };
      console.log('Device unregistered: ' + JSON.stringify(regdata));

      callback(regdata);

    }

  });

};
