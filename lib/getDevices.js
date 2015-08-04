var _ = require('lodash');
var async = require('async');
var debug = require('debug')('meshblu:getDevices');
var config = require('./../config');
var devices = require('./database').devices;
var securityImpl = require('./getSecurityImpl');
var logEvent = require('./logEvent');

module.exports = function(fromDevice, query, owner, callback) {

  function processResults(err, devicedata){
    debug('processResults');
    if(err || devicedata.length < 1) {

      devicedata = {
        "error": {
          "message": "Devices not found",
          "code": 404
        }
      };
      logEvent(403, devicedata);
      return callback(devicedata);
    }

    logEvent(403, {"devices": devicedata});
    callback({"devices": devicedata});
  }

  var fetch = {};
  // Loop through parameters to update device
  for (var param in query) {
   fetch[param] = query[param];
   if (query[param] === 'null' || query[param] === ''){
     fetch[param] = { "$exists" : false };
   }

  }
  if (_.isString(query.online)){
    fetch.online = query.online === "true";
  }

  fetch["$or"] = [
    {
      uuid: fromDevice.uuid
    },
    {
      discoverWhitelist: fromDevice.uuid
    },
    {
      discoverWhitelist: '*'
    },
    {
      discoverWhitelist: null
    },
    {
      discoverWhitelist: {
        $exists: false
      }
    },
    {
      owner: fromDevice.uuid
    }
  ];

  delete fetch.token;
  //sorts newest devices on top
  debug('getDevices start query');
  if(config.mongo && config.mongo.databaseUrl){
    devices.find(fetch, { socketid: false, _id: false, token: false}).maxTimeMS(2000).limit(1000).sort({ _id: -1 }, function(err, devicedata) {
      debug('gotDevices mongo');
      processResults(err, devicedata);
    });
  } else {
    devices.find(fetch, { socketid: false, _id: false, token: false}).limit(1000).sort({ timestamp: -1 }).exec(function(err, devicedata) {
      debug('gotDevices nedb');
      processResults(err, devicedata);
    });
  }
};
