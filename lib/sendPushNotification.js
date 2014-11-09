var request = require('request');
var config = require('./../config');

module.exports = function(device, message, callback) {

  // remove quotes around message string
  message = message.substring(1, message.length -1);
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
      if (error) {
        console.error(error);
        callback();
        return;
      }
      callback(body);
  });

};
