// var devices = require('./database').collection('devices');

// module.exports = function(req, res, next) {

//   devices.findOne({
//     uuid: {"$regex":req.params.uuid,"$options":"i"}
//   }, function(err, devicedata) {

//     if(err || devicedata.length < 1) {

//       res.json({
//         "errors": [{
//           "message": "Device not found",
//           "code": 404
//         }]
//       });
      

//     } else {

//       // remove token from results object
//       delete devicedata.token
//       console.log('Device whoami: ' + JSON.stringify(devicedata))

//       res.json(devicedata);

//     }

//   });

// };

var devices = require('./database').collection('devices');

module.exports = function(uuid, callback) {

  devices.findOne({
    uuid: {"$regex":uuid,"$options":"i"}
  }, function(err, devicedata) {

    if(err || devicedata.length < 1) {

      res.json({
        "errors": [{
          "message": "Device not found",
          "code": 404
        }]
      });
      

    } else {

      // remove token from results object
      delete devicedata.token
      console.log('Device whoami: ' + JSON.stringify(devicedata))

      callback(devicedata);

    }

  });

};