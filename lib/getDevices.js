var devices = require('./database').collection('devices');

module.exports = function(req, res, next) {

  var fetch = {};
  // Loop through parameters to update device
  for (var param in req.query) {
   // console.log(param, req.params[param]);
   fetch[param] = req.query[param];
  }
  if (req.query.online){
    fetch["online"] = Boolean((req.query.online == "true"));
  }


  devices.find(fetch, function(err, devicedata) {

    if(err || devicedata.length < 1) {

      devicedata = {
        "errors": [{
          "message": "Devices not found",
          "code": 404
        }]
      };
      require('./logEvent')(201, devicedata);
      res.json(devicedata);
      

    } else {

      // remove tokens from results object
      for (var i=0;i<devicedata.length;i++)
      { 
        delete devicedata[i].token;
      }      
      console.log('Devices: ' + JSON.stringify(devicedata));
      require('./logEvent')(201, JSON.stringify(devicedata));
      res.json(devicedata);

    }


  });

};