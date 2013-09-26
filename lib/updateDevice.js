var devices = require('./database').collection('devices');

module.exports = function(req, res, next) {

  var newTimestamp = new Date().getTime();

  var updates = {};

  // Loop through parameters to update device
  for (var param in req.params) {
   // console.log(param, req.params[param]);
   updates[param] = req.params[param];
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