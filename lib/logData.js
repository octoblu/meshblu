var moment = require('moment');
var config = require('./../config');

var data = require('./database').data;

module.exports = function(params, callback) {

  // Loop through parameters to update device sensor data
  var updates = {};
  // updates.timestamp = new Date()
  updates.timestamp = moment(data.timestamp).toISOString();

  for (var param in params) {
    console.log('param:', param);
    var parsed;
    try {
      parsed = JSON.parse(params[param]);
    } catch (e) {
      parsed = params[param];
    }
    // if(parsed)
    updates[param] = parsed.toString();
  }

  delete updates.token;

  data.insert(updates, function(err, saved) {
    // if(err || saved === 0) {
    if(err) {
      var regdata = {
        "error": {
          "message": "Device not registered",
          "code": 500
        }
      };
      // require('./logEvent')(400, regdata);
      callback(regdata);
    } else {
      console.log('Sensor data logged:', JSON.stringify(updates));

      updates._id.toString();
      delete updates._id;

      require('./logEvent')(700, updates);
      callback(updates);
    }
  });

};
