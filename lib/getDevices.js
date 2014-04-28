var devices = require('./database').collection('devices');
var config = require('./../config');

var MAX_RESULTS = config.maxSearchResults || 50;

module.exports = function(query, owner, callback) {
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

      var deviceArray = [];

      if(owner){
        deviceArray = devicedata;
      } else {
        // Now just returning an array of UUIDs that meet search requirements
        for (var i=0;i<devicedata.length;i++)
        {
          deviceArray.push(devicedata[i].uuid);
        }

      }
      console.log('Devices: ' + JSON.stringify(deviceArray));
      require('./logEvent')(403, {"devices": deviceArray});
      callback({"devices": deviceArray});
    }
  });
};
