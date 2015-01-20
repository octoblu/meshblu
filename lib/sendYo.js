var request = require('request');
var config = require('./../config');
var getDevice = require('./getDevice');

var makeRequest = function(yoToken, yoUser, callback) {
  var url = 'http://api.justyo.co/yo/';
  var params = {json: {'api_token': yoToken, 'username': yoUser}};

  request.post(url, params, function (error, response, body) {
    callback(error, body);
  });
}

module.exports = function(uuid, message, callback) {
  getDevice(uuid, function(error, device) {
    if (error) {
      callback(error);
      return;
    }

    makeRequest(config.yo.token, device.yoUser, function(error, body) {
      body.uuid = uuid
      callback(body);
    });
  });
};
