var whoAmI = require('./whoAmI');
var logEvent = require('./logEvent');

module.exports = function(io, data, fn){
  console.log('gateway api req received', data);

  whoAmI(data.uuid, true, function(check){
    console.log('whoami', check);

    if(check.error ){
      return fn(check);
    }

    if(check.type == 'gateway' && check.uuid == data.uuid && check.token == data.token){
      if(check.online){
        console.log("gateway online with socket id:", check.socketId);

        io.sockets.socket(check.socketId).emit("config", {devices: data.uuid, token: data.token, method: data.method, name: data.name, type: data.type, options: data.options}, function(results){
          console.log(results);

          results.toUuid = check;
          logEvent(600, results);

          try{
            fn(results);
          } catch (e){
            console.log(e);
          }

        });

      } else {

        console.log("gateway offline");

        var results = {
          "error": {
            "message": "Gateway offline",
            "code": 404
          }
        };

        try{
          fn(results);
        } catch (e){
          console.log(e);
        }

        results.toUuid = check;
        logEvent(600, results);

      }

    } else {

      var gatewaydata = {
        "error": {
          "message": "Gateway not found",
          "code": 404
        }
      };
      try{
        fn(gatewaydata);
      } catch (e){
        console.log(e);
      }
      logEvent(600, gatewaydata);

    }
  });
};
