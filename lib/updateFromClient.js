var getDevice = require('./getDevice');
var logEvent = require('./logEvent');
var securityImpl = require('./getSecurityImpl');
var updateDevice = require('./updateDevice');

function handleUpdate(fromDevice, data, callback){
  callback = callback || function(){};

  data.uuid = data.uuid || fromDevice.uuid;

  getDevice(data.uuid, function(error, device){
    if(error) {
      callback(error);
      return;
    }

    if (!securityImpl.canConfigure(fromDevice, device, data)) {
      callback({error: {message: 'unauthorized', code: 401} });
      return;
    }

    delete data.token;
    updateDevice(device.uuid, data, function(error, results){
      results.fromUuid = fromDevice.uuid;
      results.from = fromDevice;
      logEvent(401, results);

      try{
        callback(results);
      } catch (e){
        console.error(e);
      }

    });
  });

}

module.exports = handleUpdate;
