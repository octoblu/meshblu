var whoAmI = require('./whoAmI');
var logEvent = require('./logEvent');
var securityImpl = require('./getSecurityImpl');
var updateDevice = require('./updateDevice');

function handleUpdate(fromDevice, data, fn){
  fn = fn || function(){};

  data.uuid = data.uuid || fromDevice.uuid;

  whoAmI(data.uuid, true, function(check){

    if(check.error){
      return fn(check);
    }

    if((data.token && check.token === data.token) || securityImpl.canUpdate(fromDevice, check, data)){
    // if(securityImpl.canUpdate(fromDevice, check, data)){
      updateDevice(data.uuid, data, function(results){
        results.fromUuid = fromDevice.uuid;
        results.from = fromDevice;
        logEvent(401, results);

        try{
          fn(results);
        } catch (e){
          console.error(e);
        }

      });
    }else{
      fn({error: {message: 'unauthorized', code: 401} });
    }
  });

}

module.exports = handleUpdate;
