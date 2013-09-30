// var devices = require('./database').collection('devices');
// var uuid = require('node-uuid');

// module.exports = function(req, res, next) {

//   var rand = function() {
//       return Math.random().toString(36).substr(2); // remove `0.`
//   };

//   var token = function() {
//       return rand() + rand(); // to make it longer
//   };

//   var newUuid = uuid.v1();
//   var newTimestamp = new Date().getTime();
//   var token = token();

//   var updates = {};
//   // Loop through parameters to update device
//   for (var param in req.params) {
//    // console.log(param, req.params[param]);
//    updates[param] = req.params[param];
//   }
//   if (req.params.channel){
//     var deviceChannel = req.params.channel;
//   } else {
//     var deviceChannel = 'main';
//   }
//   updates["uuid"] = newUuid;
//   updates["timestamp"] = newTimestamp;
//   updates["token"] = token;
//   updates["online"] = false;

//   devices.save(updates, function(err, saved) {

//     if(err) {

//       res.json({
//         "errors": [{
//           "message": "Device not registered",
//           "code": 500
//         }]
//       });
      

//     } else {    

//       console.log('Device registered: ' + JSON.stringify(updates))

//       res.json(updates);
//     }

//   });

// };


var devices = require('./database').collection('devices');
var uuid = require('node-uuid');

module.exports = function(params, callback) {

  var rand = function() {
      return Math.random().toString(36).substr(2); // remove `0.`
  };

  var token = function() {
      return rand() + rand(); // to make it longer
  };

  var newUuid = uuid.v1();
  var newTimestamp = new Date().getTime();
  var token = token();

  var updates = {};
  // Loop through parameters to update device
  for (var param in params) {
   // console.log(param, req.params[param]);
   updates[param] = params[param];
  }
  if (params["channel"]){
    var deviceChannel = params["channel"];
  } else {
    var deviceChannel = 'main';
  }
  updates["uuid"] = newUuid;
  updates["timestamp"] = newTimestamp;
  updates["token"] = token;
  updates["channel"] = deviceChannel;
  updates["online"] = false;

  devices.save(updates, function(err, saved) {

    if(err || saved == 0) {

      var regdata = {
        "errors": [{
          "message": "Device not registered",
          "code": 500
        }]
      };
      callback(regdata);

    } else {    

      console.log('Device registered: ' + JSON.stringify(updates))

      callback(updates);
    }

  });

};