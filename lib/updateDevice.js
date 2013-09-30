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
  updates["timestamp"] = newTimestamp;

  devices.update({
    uuid: {"$regex":req.params.uuid,"$options":"i"}, token: req.params.token
  }, {
    $set: updates
  }, function(err, saved) {

    if(err || saved == 0) {

      console.log("Device not found or token not valid");

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
      // merge objects
      for (var attrname in updates) { regdata[attrname] = updates[attrname]; }

      // remove token from results object
      delete regdata.token
      console.log('Device udpated: ' + JSON.stringify(regdata))

      res.json(regdata);
    }

  });

};