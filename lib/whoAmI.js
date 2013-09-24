var devices = require('./database').collection('devices');

module.exports = function(req, res, next) {

  devices.findOne({
    uuid: {"$regex":req.params.uuid,"$options":"i"}
  }, function(err, devicedata) {

    if(err || devicedata.length < 1) {

      res.json({
        "errors": [{
          "message": "Device not found",
          "code": 404
        }]
      });
      

    } else {

      var regdata = {
        uuid: devicedata.uuid,
        timestamp: devicedata.timestamp,
        deviceName: devicedata.deviceName,
        deviceDescription: devicedata.deviceDescription,
        channel: devicedata.channel,
        online: devicedata.online
      };
      console.log('Device whoami: ' + JSON.stringify(regdata))

      res.json(regdata);

    }

  });

};