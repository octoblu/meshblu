var devices = require('./database').collection('devices');
var uuid = require('node-uuid');

module.exports = function(params, callback) {

  var rand = function() {
      return Math.random().toString(36).substr(2); // remove `0.`
  };

  var generateToken = function() {
      return rand() + rand(); // to make it longer
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
    updates[param] = parsed.toString();
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
      uuid: {"$regex":params.uuid,"$options":"i"}
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
    updates.timestamp = newTimestamp;
    updates.token = token;
    updates.channel = deviceChannel;
    updates.online = devicePresence;
    updates.ipAddress = deviceIpAddress;

    devices.save(updates, function(err, saved) {
      // if(err || saved === 0) {
      if(err) {
        var regdata = {
          "error": {
            "message": "Device not registered",
            "code": 500
          }
        };
        require('./logEvent')(400, regdata);
        callback(regdata);
      } else {
        console.log('Device registered: ' + JSON.stringify(updates));

        require('./logEvent')(400, updates);
        callback(updates);
      }
    });
  };

};