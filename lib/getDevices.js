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

    var checkCanDiscover = function(device, next){
      securityImpl.canDiscover(fromDevice, device, query, function(error, permission) {
        delete device.socketid;
        delete device._id;
        delete device.token;
        next(permission && !error);
        // deviceResults.push(device);
      });
    };

    debug('checkCanDiscover');
    async.filter(devicedata, checkCanDiscover, function(devicesAllowed){
      debug('checkedCanDiscover');
      logEvent(403, {"devices": devicesAllowed});
      callback({"devices": devicesAllowed});
    });
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

  delete fetch.token;
  //sorts newest devices on top
  debug('getDevices start query');
  if(config.mongo && config.mongo.databaseUrl){
    devices.find(fetch).limit(1000).sort({ _id: -1 }, function(err, devicedata) {
      debug('gotDevices mongo');
      processResults(err, devicedata);
    });
  } else {
    devices.find(fetch).limit(1000).sort({ timestamp: -1 }).exec(function(err, devicedata) {
      debug('gotDevices nedb');
      processResults(err, devicedata);
    });
  }
};
