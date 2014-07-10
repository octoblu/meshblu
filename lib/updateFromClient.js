var whoAmI = require('./whoAmI');
var logEvent = require('./logEvent');
var securityImpl = require('./getSecurityImpl');
var updateDevice = require('./updateDevice');

function handleUpdate(fromDevice, data, fn){

  data.uuid = data.uuid || fromDevice.uuid;

  whoAmI(data.uuid, false, function(check){

    if(check.error){
      return fn(check);
    }

    if(securityImpl.canUpdate(fromDevice, check)){
      updateDevice(data.uuid, data, function(results){
        console.log('update results', results);
        results.fromUuid = fromDevice;
        logEvent(401, results);

        try{
          fn(results);
        } catch (e){
          console.log(e);
        }

      });
    }else{
      fn({error: {message: 'unauthorized', code: 401} });
    }
  });

}

module.exports = handleUpdate;
