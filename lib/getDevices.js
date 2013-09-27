var devices = require('./database').collection('devices');

module.exports = function(req, res, next) {


  devices.find({
    // uuid: {"$regex":req.params.uuid,"$options":"i"}
  }, function(err, devicedata) {

    if(err || devicedata.length < 1) {

      res.json({
        "errors": [{
          "message": "Devices not found",
          "code": 404
        }]
      });
      

    } else {

      // remove tokens from results object
      for (var i=0;i<devicedata.length;i++)
      { 
        delete devicedata[i].token;
      }      
      console.log('Devices: ' + JSON.stringify(devicedata));

      res.json(devicedata);

    }

  });

};