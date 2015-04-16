var config = require('./../config');
var securityImpl = require('./getSecurityImpl');

var devices = require('./database').devices;
var _ = require('lodash');
var async = require('async');

module.exports = function(fromDevice, query, owner, callback) {

  function processResults(err, devicedata){
    if(err || devicedata.length < 1) {

      devicedata = {
        "error": {
          "message": "Devices not found",
          "code": 404
        }
      };
      require('./logEvent')(403, devicedata);
      callback(devicedata);


    } else {

      var deviceResults = [];

      var checkCanDiscover = function(device, next){
        securityImpl.canDiscover(fromDevice, device, function(error, device) {

          if(error || !device) {
            return;
          }

          deviceResults.push(device);
          delete device.socketid;
          delete device._id;
          delete device.token;
          next();
        });
      };

      require('./logEvent')(403, {"devices": deviceResults});

      async.eachSeries(devicedata, checkCanDiscover, function(){
        callback({"devices": deviceResults});
      });
    }

  }

  // query = JSON.parse(query);
  var fetch = {};
  // Loop through parameters to update device
  for (var param in query) {
   fetch[param] = query[param];
   if (query[param] === 'null' || query[param] === ''){
     fetch[param] = { "$exists" : false };
   }

  }
  if (query.online){
    fetch.online = query.online === "true";
  }

  delete fetch.token;
  //sorts newest devices on top
  if(config.mongo && config.mongo.databaseUrl){
    devices.find(fetch).sort({ _id: -1 }, function(err, devicedata) {
      processResults(err, devicedata);
    });
  } else {
    devices.find(fetch).sort({ timestamp: -1 }).exec(function(err, devicedata) {
      processResults(err, devicedata);
    });
  }
};
