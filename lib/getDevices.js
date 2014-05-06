var devices = require('./database').collection('devices');
var config = require('./../config');
var securityImpl = require('./getSecurityImpl');

var MAX_RESULTS = config.maxSearchResults || 50;

function filterSearchResults(fromUuid, results){
  var filteredDevices = [];
  if(results && results.devices){
    results.devices.forEach(function(device){
      if(securityImpl.canView(fromUuid, device)){
        filteredDevices.push(device);
      }
    });

  }
  return filteredDevices;
}

module.exports = function(fromUuid, query, ipAddress, owner, callback) {
  // query = JSON.parse(query);
  var fetch = {};
  // Loop through parameters to update device
  for (var param in query) {
   // console.log(param, req.params[param]);
   fetch[param] = query[param];
   console.log(query[param]);
   if (query[param] === 'null' || query[param] === ''){
     console.log('null value found');
     fetch[param] = { "$exists" : false };
   }

  }
  if (query.online){
    fetch.online = query.online === "true";
  }
  console.log(fetch);
  devices.find(fetch, {'limit':MAX_RESULTS}, function(err, devicedata) {

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

      devicedata.forEach(function(device){
        if(securityImpl.canView(fromUuid, device, ipAddress)){
          deviceResults.push(device);
        }
      });

      deviceResults.forEach(function(device){
        //TODO maybe configurable secure props?
        if(!owner && fromUuid != device.uuid){
          delete device.token;
          delete device.socketid;
          delete device._id;
          delete device.sendWhitelist;
          delete device.sendBlacklist;
          delete device.viewWhitelist;
          delete device.viewBlacklist;
          delete device.owner;
        }
      });

      console.log('Devices: ' + JSON.stringify(deviceResults));
      require('./logEvent')(403, {"devices": deviceResults});
      callback({"devices": deviceResults});
    }
  });
};
