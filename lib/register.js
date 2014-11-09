var uuid = require('node-uuid');
var moment = require('moment');
var config = require('./../config');

var devices = require('./database').devices;

module.exports = function(params, callback) {

  function pad(width, string, padding) {
    return (width <= string.length) ? string : pad(width, padding + string, padding)
  }

  var rand = function() {
      return Math.random().toString(36).substr(2); // remove `0.`
  };

  var generateToken = function() {
      return pad(32, rand() + rand(), '0'); // to make it longer
  };

  var newUuid = uuid.v1();
  var newTimestamp = new Date().getTime();

  var updates = {};

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
    updates[param] = parsed;
  }


  var deviceChannel;
  if (params.channel){
    deviceChannel = params.channel;
  } else {
    deviceChannel = 'main';
  }

  var devicePresence;
  if(typeof params.online === 'string'){
    if (params.online == "true"){
      devicePresence = true;  
    } else if(params.online == "false"){
      devicePresence = false;  
    } 
  } else if (typeof params.online === 'boolean'){
    devicePresence = params.online;
  } else {
    devicePresence = false;
  }

  var deviceIpAddress;
  var deviceGeo;
  if (params.ipAddress){
    deviceIpAddress = params.ipAddress;
    try {
      var geoip = require('geoip-lite');
      deviceGeo = geoip.lookup(params.ipAddress);
    } catch(geoip){
      deviceGeo = null;
    }
  } else {
    deviceIpAddress = "";
    deviceGeo = null;
  }

  var token;
  if (params.token){
    token = params.token;
  } else {
    token = generateToken();
  }

  var myUuid;
  if (params.uuid){
    devices.findOne({
      uuid: params.uuid
    }, function(err, devicedata) {
      if(err || !devicedata || devicedata.length < 1) {
        myUuid = params.uuid;
        writeUuid();
      } else {
        // myUuid = uuid.v1();
        // writeUuid();

        // Return an error now if UUID is already registered rather than auto generate a new uuid
        var regdata = {
          "error": {
            "message": "Device UUID already registered",
            "code": 500
          }
        };
        callback(regdata);

      }
    });
  } else {
    myUuid = uuid.v1();
    writeUuid();
  }

  function writeUuid() {
    updates.uuid = myUuid;
    updates.timestamp = moment(newTimestamp).toISOString();
    updates.token = token;
    updates.channel = deviceChannel;
    updates.online = devicePresence;
    updates.ipAddress = deviceIpAddress;
    updates.geo = deviceGeo;
    updates.socketid = params.socketid;

    devices.insert(updates, function(err, saved) {

      if(err) {
        var regdata = {
          "error": {
            "message": "Device not registered",
            "code": 500
          }
        };
        callback(regdata);
      } else {
        updates._id.toString();
        delete updates._id;
        callback(updates);
      }
    });
  }

};
