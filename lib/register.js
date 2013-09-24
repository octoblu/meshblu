var devices = require('./database').collection('devices');
var uuid = require('node-uuid');

module.exports = function(req, res, next) {

  var newUuid = uuid.v1();
  var newTimestamp = new Date().getTime();

  if (req.params.name){
    var deviceName = req.params.name;
  } else {
    var devicename = '';
  }
  if (req.params.description){
    var deviceDescription = req.params.description;
  } else {
    var deviceDescription = '';
  }
  if (req.params.channel){
    var deviceChannel = req.params.channel;
  } else {
    var deviceChannel = 'main';
  }

  devices.save({
    uuid: newUuid,
    timestamp: newTimestamp,
    deviceName: deviceName,
    deviceDescription: deviceDescription,
    channel: deviceChannel,
    online: false
  }, function(err, saved) {

    if(err) {

      res.json({
        "errors": [{
          "message": "Device not registered",
          "code": 500
        }]
      });
      

    } else {    

      var regdata = {
        uuid: newUuid,
        timestamp: newTimestamp,
        deviceName: deviceName,
        deviceDescription: deviceDescription,
        channel: deviceChannel,
        online: false
      };
      console.log('Device registered: ' + JSON.stringify(regdata))

      res.json(regdata);
    }

  });

};