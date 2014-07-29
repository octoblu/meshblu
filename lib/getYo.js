var config = require('./../config');

var devices = require('./database').devices;

module.exports = function(yoUsername, callback) {
  console.log('yoUser', yoUsername);
  var regex = new RegExp(["^",yoUsername,"$"].join(""),"i");
  devices.findOne({
    yoUser: regex
  }, function(err, devicedata) {
    if(err || !devicedata || devicedata.length < 1) {
      console.log('Yo user not found');
      callback('Yo user not found');
    } else {
      console.log('UUID: ' + devicedata.uuid);
      callback(null, devicedata);
    }
  });
};
