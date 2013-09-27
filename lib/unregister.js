var devices = require('./database').collection('devices');

module.exports = function(req, res, next) {

  var newTimestamp = new Date().getTime();

  devices.remove({
    uuid: {"$regex":req.params.uuid,"$options":"i"}, token: req.params.token
  }, function(err, devicedata) {
    console.log(devicedata);

    if(err || devicedata == 0) {

      res.json({
        "errors": [{
          "message": "Device not found or token not valid",
          "code": 404
        }]
      });
      

    } else {

      var regdata = {
        uuid: req.params.uuid,
        timestamp: newTimestamp
      };
      console.log('Device unregistered: ' + JSON.stringify(regdata))

      res.json(regdata);    

    }

  });

};