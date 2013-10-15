var devices = require('./database').collection('devices');

module.exports = function(uuid, callback) {
  console.log(uuid);
  devices.findOne({
    uuid: {"$regex":uuid,"$options":"i"}
  }, function(err, devicedata) {

    if(err || devicedata == undefined || devicedata.length < 1) {

      var regdata = {
        "errors": [{
          "message": "Device not found",
          "code": 404
        }]
      };
      callback(regdata);      
      

    } else {

      // remove token from results object
      delete devicedata.token
      console.log('Device whoami: ' + JSON.stringify(devicedata))

      callback(devicedata);

    }

  });

};