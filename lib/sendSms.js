var request = require('request');
var config = require('./../config');

var devices = require('./database').devices;

module.exports = function(uuid, message, callback) {
  devices.findOne({
    uuid: uuid
  }, function(err, devicedata) {
    if(err || !devicedata || devicedata.length < 1) {
      console.log('uuid not found');
      callback({});
    } else {
      // request.post('https://' + config.plivo.authId + ':' + config.plivo.authToken + '@api.plivo.com/v1/Account/' + config.plivo.authId + '/Message/',
      request.post('https://' + devicedata.plivoAuthId + ':' + devicedata.plivoAuthToken + '@api.plivo.com/v1/Account/' + devicedata.plivoAuthId + '/Message/',
        {json: {'src': '17144625921', 'dst': devicedata.phoneNumber,  'text': message}}
      , function (error, response, body) {
          body.uuid = uuid
          console.log(body);
          // require('./logEvent')(302, body);
          callback(body);
      });
    }
  });
};
