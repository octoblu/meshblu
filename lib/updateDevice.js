var devices = require('./database').collection('devices');

module.exports = function(req, res, next) {

  var newTimestamp = new Date().getTime();

  var updates = {};
  if (req.params.name){
    updates["deviceName"] = req.params.name;
  }
  if (req.params.description){
    updates["deviceDescription"] = req.params.description;
  }
  if (req.params.channel){
    updates["deviceChannel"] = req.params.channel;
  }
  if (req.params.online){
    updates["online"] = Boolean((req.params.online == "true"));
  }

  devices.update({
    uuid: req.params.uuid
  }, {
    $set: updates
  }, function(err, saved) {

    if(err || saved == 0) {

      res.json({
        "errors": [{
          "message": "Device not found",
          "code": 404
        }]
      });
      

    } else {    

      var regdata = {
        uuid: req.params.uuid,
        timestamp: newTimestamp
      };
      // merge objects
      for (var attrname in updates) { regdata[attrname] = updates[attrname]; }

      console.log('Device udpated: ' + JSON.stringify(regdata))

      res.json(regdata);
    }

  });

};