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
    console.log('gateway api req received', data);

    whoAmI(data.uuid, true, function(check){
      console.log('whoami', check);

      if((check.type === 'gateway' || check.type === 'hub') && check.uuid === data.uuid && check.token === data.token){
        // if(check.online){
          //console.log('configging', data);
          data.fromUuid = fromDevice.uuid;
          return clientEmitter('config', check, data);

        // } else {

        //   console.log("gateway offline");

        //   data.error = {
        //     message: "Gateway offline",
        //     code: 404
        //   };

        //   return clientEmitter('messageAck', fromDevice, data);

        // }

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
