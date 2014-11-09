var moment = require('moment');
var config = require('./../config');
var clearCache = require('./clearCache');
var _ = require('lodash');
var devices = require('./database').devices;

module.exports = function(uuid, params, callback) {
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
  if(action === '$set'){
    updates = _.omit(params, function(value, key){
      // Mongo won't store $'d keys, so we don't either.
      return key[0] === '$';
    });
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

    if(err || saved === 0 || (saved && config.mongo && !saved.updatedExisting)) {
      regdata = {
        "error": {
          "message": "Device not found or token not valid",
          "code": 404
        }
      };
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

      // is there a secondary action we need to take
      if(action !== "$set") {
        // clean up the object before we proceed
        var getRidOf = ["uuid","timestamp","action","token","$$hashKey"];
        for (var attrname in secondaryObj) {
          regdata[attrname] = secondaryObj[attrname];
          if(getRidOf.indexOf(attrname)!== -1){
            delete secondaryObj[attrname];
          }
        }
        // remove token from results object
        delete regdata.token;
        delete regdata["_id"];
        delete regdata["$$hashKey"];

        var qryObj = {};
        qryObj[action] = secondaryObj;
        devices.update({
          uuid: uuid
        }, qryObj, function(err, saved) {

          if(err || saved === 0) {

            regdata = {
              "error": {
                "message": "Unable to perform secondary operation",
                "code": 404
              }
            };
            callback(regdata);
          } else {
            callback(regdata);
          }
        });
      } else {
        callback(regdata);
      }
    }
  });
};
