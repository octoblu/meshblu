var devices = require('./database').collection('devices');

module.exports = function(uuid, params, callback) {

  var newTimestamp = new Date().getTime();

  var updates = {};
  // Loop through parameters to update device
  for (var param in params) {
    try {
      var parsed = JSON.parse(params[param]);
    } catch (e) {
      var parsed = params[param];
    }
    updates[param] = parsed;
  }

  if (params["online"]){
    updates["online"] = Boolean((params["online"] == "true"));
  }
  updates["timestamp"] = newTimestamp;

  devices.update({
    uuid: {"$regex":uuid,"$options":"i"}, token: params["token"]
  }, {
    $set: updates
  }, function(err, saved) {

    if(err || saved == 0) {

      console.log("Device not found or token not valid");

      var regdata = {
        "errors": [{
          "message": "Device not found or token not valid",
          "code": 404
        }]
      };
      callback(regdata);
      

    } else {    

      var regdata = {
        uuid: uuid,
        timestamp: newTimestamp
      };
      // merge objects
      for (var attrname in updates) { regdata[attrname] = updates[attrname]; }

      // remove token from results object
      delete regdata.token
      console.log('Device udpated: ' + JSON.stringify(regdata))

      callback(regdata);
    }

  });

};