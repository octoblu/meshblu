var config = require('./../config');
var securityImpl = require('./getSecurityImpl');

var devices = require('./database').devices;
var _ = require('lodash');

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

      _.each(devicedata, function(device){
        if(securityImpl.canDiscover(fromDevice, device)){
          deviceResults.push(device);

          delete device.token;
          delete device.socketid;
          delete device._id;

          //TODO maybe configurable secure props?
          if(!owner && fromDevice.uuid != device.uuid){
            delete device.sendWhitelist;
            delete device.sendBlacklist;
            delete device.receiveWhitelist;
            delete device.receiveBlacklist;
            delete device.discoverWhitelist;
            delete device.discoverBlacklist;
            delete device.configureWhitelist;
            delete device.configureBlacklist;
            delete device.owner;
          }

        }
      });

      require('./logEvent')(403, {"devices": deviceResults});
      callback({"devices": deviceResults});
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
