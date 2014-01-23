var devices = require('./database').collection('devices');

module.exports = function(query, owner, callback) {
  // query = JSON.parse(query);
  var fetch = {};
  // Loop through parameters to update device
  for (var param in query) {
   // console.log(param, req.params[param]);
   fetch[param] = query[param];
  }
  if (query.online){
    fetch.online = query.online === "true";
  }
  console.log(fetch);
  devices.find(fetch, function(err, devicedata) {

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

      // // remove tokens from results object
      // for (var i=0;i<devicedata.length;i++)
      // {
      //   delete devicedata[i].token;
      // }

      var deviceArray = [];

      if(owner){
        deviceArray = devicedata
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