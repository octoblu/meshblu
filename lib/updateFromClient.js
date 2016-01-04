var _               = require('lodash');
var getDevice       = require('./getDevice');
var logEvent        = require('./logEvent');
var securityImpl    = require('./getSecurityImpl');
var oldUpdateDevice = require('./oldUpdateDevice');

function handleUpdate(fromDevice, data, callback){
  callback = callback || function(){};

  data.uuid = data.uuid || fromDevice.uuid;
  getDevice(data.uuid, function(error, device){
    if(error) {
      callback(error);
      return;
    }

    securityImpl.canConfigure(fromDevice, device, data, function(error, permission) {
      if(!permission || error) {
        callback({error: {message: 'unauthorized', code: 401} });
        return;
      }

      delete data.token;
      oldUpdateDevice(device.uuid, data, function(error, results){
        if (error) {
          callback({error: {message: 'update failed', code: 422}});
          return;
        }
        var logResults;
        if (results) {
          logResults = _.clone(results);
          logResults.fromUuid = fromDevice.uuid;
          logResults.from = fromDevice;
        }
        logEvent(401, logResults);

        callback(results);
      });
    });
  });
}

module.exports = handleUpdate;
