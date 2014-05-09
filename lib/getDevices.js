var devices = require('./database').collection('devices');
var config = require('./../config');
var securityImpl = require('./getSecurityImpl');

var MAX_RESULTS = config.maxSearchResults || 50;

module.exports = function(fromDevice, query, owner, callback) {
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
  //sorts newest devices on top
  devices.find(fetch).limit(MAX_RESULTS).sort({ $natural: -1 }, function(err, devicedata) {

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
        if(securityImpl.canView(fromDevice, device)){
          deviceResults.push(device);

          //TODO maybe configurable secure props?
          if(!owner && fromDevice.uuid != device.uuid){
            delete device.token;
            delete device.socketid;
            delete device._id;
            delete device.sendWhitelist;
            delete device.sendBlacklist;
            delete device.viewWhitelist;
            delete device.viewBlacklist;
            delete device.owner;
          }

        }
      });

      console.log('Devices: ' + JSON.stringify(deviceResults));
      require('./logEvent')(403, {"devices": deviceResults});
      callback({"devices": deviceResults});
    }
  });
};
