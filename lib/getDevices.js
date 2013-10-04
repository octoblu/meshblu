var devices = require('./database').collection('devices');

module.exports = function(query, callback) {

  var fetch = {};
  // Loop through parameters to update device
  for (var param in query) {
   // console.log(param, req.params[param]);
   fetch[param] = query[param];
  }
  if (query["online"]){
    fetch["online"] = Boolean((query["online"] == "true"));
  }
  console.log(fetch);

  devices.find(fetch, function(err, devicedata) {

    if(err || devicedata.length < 1) {

      devicedata = {
        "errors": [{
          "message": "Devices not found",
          "code": 404
        }]
      };
      require('./logEvent')(201, devicedata);
      callback(devicedata);
      

    } else {

      // // remove tokens from results object
      // for (var i=0;i<devicedata.length;i++)
      // { 
      //   delete devicedata[i].token;
      // }      

      // Now just returning an array of UUIDs that meet search requirements
      var deviceArray = new Array();
      for (var i=0;i<devicedata.length;i++)
      { 
        deviceArray.push(devicedata[i].uuid); 
      }      
      console.log('Devices: ' + JSON.stringify(deviceArray));
      require('./logEvent')(201, JSON.stringify(deviceArray));
      callback(deviceArray);

    }


  });

};