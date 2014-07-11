var request = require('request');
var config = require('./../config');

module.exports = function(device, message, callback) {

  // remove quotes around message string
  message = message.substring(1, message.length -1);
  console.log('Calling Urban Airship API...');
  request.post("https://" + config.urbanAirship.key + ":" + config.urbanAirship.secret + "@go.urbanairship.com/api/push/",
    { headers: {
        "Content-Type": "application/json",
        "Accept": "application/vnd.urbanairship+json; version=3;"
      },
      json:{
        "audience" : {
            "device_token" : device.pushID
        },
        "notification" : {
             "alert" : message
        },
        "device_types" : "all"
      }
    }, function (error, response, body) {
      console.log(error, body);
      callback(body);
  });

};
