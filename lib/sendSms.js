var devices = require('./database').collection('devices');
var request = require('request');

module.exports = function(uuid, message, callback) {
  devices.findOne({
    uuid: {"$regex":uuid,"$options":"i"}
  }, function(err, devicedata) {
    if(err || !devicedata || devicedata.length < 1) {
      console.log('uuid not found');
      callback({});
    } else {
      console.log('UUID: ' + devicedata.uuid);
      // curl -i -X POST  -H "Accept: application/json" -H "Content-type: application/json" -d '{"src":"17144625921","dst":"14803813574", "text":"hello"}' https://MAYTQ3YZKYMJI1MJAXYT:NDI3NzQ1ZDE5NzQxMjNlNmJiOTk1ZThmOGIwNjA0@api.plivo.com/v1/Account/MAYTQ3YZKYMJI1MJAXYT/Message/ 
      request.post('https://api.plivo.com/v1/Account/MAYTQ3YZKYMJI1MJAXYT', 
        {json: {'src': '17144625921', 'dst': devicedata.uuid,  'text': message}}
      , function (error, response, body) {
          data = JSON.parse(body);
          if(err || saved === 0) {
            var plivodata = {
              "error": {
                "message": "Device not registered",
                "code": 500
              }
            };
            require('./logEvent')(400, plivodata);
            callback(regdata);
          } else {
            console.log('Device registered: ' + JSON.stringify(updates));

            require('./logEvent')(400, updates);
            callback(updates);
          }          
          callback(data);
      });      
    }
  });
};

