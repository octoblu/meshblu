var config = require('./../config');

var devices = require('./database').devices;

module.exports = function(yoUsername, callback) {
  var regex = new RegExp(["^",yoUsername,"$"].join(""),"i");
  devices.findOne({
    yoUser: regex
  }, function(err, devicedata) {
    if(err || !devicedata || devicedata.length < 1) {
      callback('Yo user not found');
    } else {
      callback(null, devicedata);
    }
  });
};
