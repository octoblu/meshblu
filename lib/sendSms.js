var request = require('request');
var config = require('./../config');
var getDevice = require('./getDevice');

var makeRequest = function(plivoAuthId, plivoAuthToken, phoneNumber, message, callback) {
  var url = 'https://' + plivoAuthId + ':' + plivoAuthToken + '@api.plivo.com/v1/Account/' + plivoAuthId + '/Message/';
  var params = {json: {'src': '17144625921', 'dst': phoneNumber,  'text': message}};

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

    makeRequest(device.plivoAuthId, device.plivoAuthToken, device.phoneNumber, message, function(error, body) {
      body.uuid = uuid
      callback(body);
    });
  });
};
