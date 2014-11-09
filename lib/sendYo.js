var request = require('request');
var config = require('./../config');

var devices = require('./database').devices;

module.exports = function(uuid, callback) {
  devices.findOne({
    uuid: uuid
  }, function(err, devicedata) {
    if(err || !devicedata || devicedata.length < 1) {
      callback({});
    } else {
      request.post('http://api.justyo.co/yo/',
        {json: {'api_token': config.yo.token, 'username': devicedata.yoUser}}
      , function (error, response, body) {
          if (error) {
            console.error(error);
            callback();
            return;
          }
          body.uuid = uuid
          callback(body);
      });
    }
  });
};
