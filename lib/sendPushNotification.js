var request = require('request');
var config = require('./../config');

module.exports = function(device, message, callback) {

  // curl -X POST -u "<application key>:<application master secret>" \
  //  -H "Content-Type: application/json" \
  //  -H "Accept: application/vnd.urbanairship+json; version=3;" \
  //  --data '{"audience": {"alias": "myalias"}, "notification": {"alert": "Hello!"}, "device_types": ["ios"]}' \
  //  https://go.urbanairship.com/api/push/

  request.post('https://' + config.urbanAirship.key + ':' + config.urbanAirship.secret + '@go.urbanairship.com/api/push/',

    {
       "audience": {"device_token": device.pushToken},
       "notification": {
          "ios": {
             "alert" : {
                "body" : message,
                "action-loc-key" : "PLAY"
             },
          },
       "device_types": ["ios"]
    }

  , function (error, response, body) {
      body.uuid = uuid
      console.log(body);
      callback(body);
  });

};
