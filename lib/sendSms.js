var devices = require('./database').collection('devices');
var request = require('request');
var config = require('./../config');

module.exports = function(uuid, message, callback) {
  devices.findOne({
    uuid: {"$regex":uuid,"$options":"i"}
  }, function(err, devicedata) {
    if(err || !devicedata || devicedata.length < 1) {
      console.log('uuid not found');
      callback({});
    } else {
      request.post('https://' + config.plivo.authId + ':' + config.plivo.authToken + '@api.plivo.com/v1/Account/' + config.plivo.authId + '/Message/', 
        {json: {'src': '17144625921', 'dst': devicedata.phoneNumber,  'text': message}}
      , function (error, response, body) {
          body.uuid = uuid
          console.log(body);
          require('./logEvent')(302, body);
          callback(body);
      });      
    }
  });
};

