var request = require('request');
var config = require('./../config');

module.exports = function(device, message, callback) {

  message = message.substring(1, message.length -1);

  request.post("https://" + config.urbanAirship.key + ":" + config.urbanAirship.secret + "@go.urbanairship.com/api/push/",
    {json:{"device_tokens": [device.pushID],
    "aps": {"alert": message}}
    }, function (error, response, body) {
      console.log(body);
      callback(body);
  });

};
