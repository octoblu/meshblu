var uuid = require('node-uuid');
var moment = require('moment');
var config = require('./../config');

var devices = require('./database').devices;

module.exports = function(params, callback) {

  console.log('register', params);

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
    try {
      parsed = JSON.parse(params[param]);
    } catch (e) {
      parsed = params[param];
    }
    //console.log('parsed param', parsed, param, params);
    if(parsed){
      updates[param] = parsed.toString();
    }else{
      console.log('invalid param', param);
    }
  }

  var deviceChannel;
  if (params.channel){
    deviceChannel = params.channel;
  } else {
    deviceChannel = 'main';
  }

  var devicePresence;
  if (params.online){
    devicePresence = params.online;
  } else {
    devicePresence = false;
  }

  var deviceIpAddress;
  if (params.ipAddress){
    deviceIpAddress = params.ipAddress;
  } else {
    deviceIpAddress = "";
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
        console.log('UUID unique');
        myUuid = params.uuid;
        writeUuid();
      } else {
        console.log('UUID not unique ');
        myUuid = uuid.v1();
        writeUuid();
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
    updates.socketid = params.socketid;

    devices.insert(updates, function(err, saved) {

      // if(err || saved === 0) {
      if(err) {
        var regdata = {
          "error": {
            "message": "Device not registered",
            "code": 500
          }
        };
        // require('./logEvent')(400, regdata);
        callback(regdata);
      } else {
        console.log('Device registered: ' + JSON.stringify(updates));

        updates._id.toString();
        delete updates._id;
        // require('./logEvent')(400, updates);
        callback(updates);
      }
    });
  }

};
