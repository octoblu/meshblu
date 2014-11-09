var whoAmI = require('./whoAmI');
var securityImpl = require('./getSecurityImpl');

module.exports = function(clientEmitter){

  function configAck(fromDevice, data){
    whoAmI(data.uuid, false, function(check){
      if(!check.error && securityImpl.canSend(fromDevice, check)){
        clientEmitter('messageAck', fromDevice, data);
      }
    });
  }

  function config(fromDevice, data){
    whoAmI(data.uuid, true, function(check){
      if((check.type === 'gateway' || check.type === 'hub') && check.uuid === data.uuid && check.token === data.token){
          data.fromUuid = fromDevice.uuid;
          return clientEmitter('config', check, data);
      } else {
        data.error = {
            "message": "Gateway not found",
            "code": 404
        };

        return clientEmitter('messageAck', fromDevice, data);
      }
    });
  }

  return {
    config: config,
    configAck: configAck
  };
};
