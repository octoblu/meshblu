var moment = require('moment');
var config = require('./../config');
var clearCache = require('./clearCache');

var devices = require('./database').devices;

module.exports = function(uuid, params, callback) {
  console.log('PARAMS->', params);
  clearCache('DEVICE_'+uuid);

  var newTimestamp = new Date().getTime();

  // by default we are doing a stanard "set", but you can pass in other actions too
  var action = "$set";
  if(params.action){
    action = "$" + params.action;
  }

  var regdata = {uuid:uuid};

  var updates = {};
  var secondaryObj = {};
  // Loop through parameters to update device
  for (var param in params) {
    var parsed;
    if(typeof params[param] === 'object'){
      try{
        parsed = JSON.parse(params[param]);
      } catch (e){
        parsed = params[param];
      }
    } else {
      parsed = params[param];
    }
    if(action === "$set"){
      updates[param] = parsed;
    }
    else if(params !== "uuid" && params !== "token") {
      secondaryObj[param] = parsed;
    }
  }

  if(typeof params.online === 'string'){
    if (params.online == "true"){
      updates.online = true;  
    } else if(params.online == "false"){
      updates.online = false;  
    } 
  } else if (typeof params.online === 'boolean'){
    updates.online = params.online;
  }
  
  updates.timestamp = moment(newTimestamp).toISOString();

  devices.update({
    uuid: uuid
  }, {
    $set: updates
  }, function(err, saved) {

    console.log('UPDATED ERR', err);
    console.log('UPDATED SAVED', saved);
    if(err || saved === 0 || (saved && config.mongo && !saved.updatedExisting)) {

      console.log("Device not found or token not valid");
      regdata = {
        "error": {
          "message": "Device not found or token not valid",
          "code": 404
        }
      };
      // require('./logEvent')(401, regdata);
      callback(regdata);


    } else {
      // merge objects
      for (var attrname in updates) {
        // lets catch anything they are making null but didnt specify an action of unset
        if(updates[attrname] === '' || updates[attrname] === null){
          action="$unset";
          secondaryObj[attrname] = updates[attrname];
        }
        regdata[attrname] = updates[attrname];
      }

      // remove token from results object
      delete regdata.token;
      console.log('Device updated: ' + JSON.stringify(regdata));

      // is there a secondary action we need to take
      if(action !== "$set") {

        // clean up the object before we proceed
        var getRidOf = ["uuid","timestamp","action","token"];
        for (var attrname in secondaryObj) {
          regdata[attrname] = secondaryObj[attrname];
          if(getRidOf.indexOf(attrname)!== -1){
            delete secondaryObj[attrname];
          }
        }
        // remove token from results object
        delete regdata.token;
        delete regdata["_id"];

        var qryObj = {};
        qryObj[action] = secondaryObj;
        //console.log(qryObj);
        devices.update({
          uuid: uuid
        }, qryObj, function(err, saved) {

          if(err || saved === 0) {

            console.log("Error doing "+action);

            regdata = {
              "error": {
                "message": "Unable to perform secondary operation",
                "code": 404
              }
            };
            // require('./logEvent')(401, regdata);
            callback(regdata);
          } else {
            console.log('Secondary complete: ' + JSON.stringify(regdata));

            // require('./logEvent')(401, regdata);
            callback(regdata);
          }

        });
      } else {
        // require('./logEvent')(401, regdata);
        callback(regdata);
      }
    }
  });
};
