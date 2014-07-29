var request = require('request');
var config = require('./../config');

var devices = require('./database').devices;

module.exports = function(uuid, callback) {
  devices.findOne({
    uuid: uuid
  }, function(err, devicedata) {
    if(err || !devicedata || devicedata.length < 1) {
      console.log('uuid not found');
      callback({});
    } else {
      console.log('sending yo to:', devicedata.yoUser);
      request.post('http://api.justyo.co/yo/',
        {json: {'api_token': config.yo.token, 'username': devicedata.yoUser}}
      , function (error, response, body) {
          console.log(error);
          body.uuid = uuid
          console.log(body);
          callback(body);
      });
    }
  });
};
