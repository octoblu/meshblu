var data = require('./database').collection('data');
var moment = require('moment');

module.exports = function(params, callback) {

  // Loop through parameters to update device sensor data
  var updates = {};
  updates.timestamp = moment().toISOString()

  for (var param in params) {
    var parsed;
    try {
      parsed = JSON.parse(params[param]);
    } catch (e) {
      parsed = params[param];
    }
    updates[param] = parsed.toString();
  }

  delete updates.token;

  data.save(updates, function(err, saved) {
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
