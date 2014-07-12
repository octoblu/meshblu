var nstatic = require('node-static');
var JSONStream = require('JSONStream');
var config = require('../config');

var whoAmI = require('./whoAmI');
var getData = require('./getData');
var logData = require('./logData');
var logEvent = require('./logEvent');
var getPhone  = require('./getPhone');
var register = require('./register');
var getEvents = require('./getEvents');
var subscribe = require('./subscribe');
var getDevices = require('./getDevices');
var authDevice = require('./authDevice');
var unregister = require('./unregister');
var claimDevice = require('./claimDevice');
var createActivity = require('./createActivity');
var getLocalDevices = require('./getLocalDevices');
var getSystemStatus = require('./getSystemStatus');
var updateFromClient = require('./updateFromClient');

function getActivity(topic, req, device, toDevice){
  return createActivity(topic, req.connection.remoteAddress, device, toDevice);
}

//psuedo middleware
function authorizeRequest(req, res, callback){

  authDevice(req.header('skynet_auth_uuid'), req.header('skynet_auth_token'), function (auth) {
      if (auth.authenticate) {
        callback(auth.device);
      }else{
        res.json(401, {error: 'unauthorized'});
      }
  });
}

function errorResponse(error, res){
  if(error.code){
    res.json(error.code, error);
  }else{
    res.json(400, error);
  }
}

function setupHttpRoutes(server, skynet){

    // curl http://localhost:3000/status
  server.get('/status', function(req, res){
    console.log('STATUS', req);
    skynet.sendActivity(getActivity('',req));
    res.setHeader('Access-Control-Allow-Origin','*');
    getSystemStatus(function(data){
      console.log(data);
      // io.sockets.in(req.params.uuid).emit('message', data)
      if(data.error){
        errorResponse(data.error, res);
      } else {
        res.json(data);
      }

    });
  });

  // curl http://localhost:3000/ipaddress
  server.get('/ipaddress', function(req, res){
    skynet.sendActivity(getActivity('',req));
    res.setHeader('Access-Control-Allow-Origin','*');
    res.json({ipAddress: req.connection.remoteAddress});
  });



  // curl http://localhost:3000/devices
  // curl http://localhost:3000/devices?key=123
  // curl http://localhost:3000/devices?online=true
  // server.get('/devices/:uuid', function(req, res){
  server.get('/devices', function(req, res){
    skynet.sendActivity(getActivity('',req));
    authorizeRequest(req, res, function(fromDevice){
      getDevices(fromDevice, req.query, false, function(data){
          if(data.error){
            errorResponse(data.error, res);
          }else{
            res.json(data);
          }
        });
    });
  });

  server.get('/devices/:uuid', function(req, res){
    skynet.sendActivity(getActivity('',req));
    authorizeRequest(req, res, function(fromDevice){
      getDevices(fromDevice, {uuid: req.params.uuid}, false, function(data){
          if(data.error){
            errorResponse(data.error, res);
          }else{
            res.json(data);
          }
        });
    });
  });

  server.get('/localdevices', function(req, res){
    skynet.sendActivity(getActivity('',req));
    authorizeRequest(req, res, function(fromDevice){
      if(req.query.overrideIp && config.skynet_override_token && req.header('Skynet_override_token') == config.skynet_override_token){
        fromDevice.ipAddress = req.query.overrideIp;
      }else{
        fromDevice.ipAddress = req.connection.remoteAddress;
      }

      getLocalDevices(fromDevice, false, function(data){
        if(data.error){
          errorResponse(data.error, res);
        }else{
          res.json(data);
        }
      });
    });

  });

  server.put('/claimdevice/:uuid', function(req, res){
    skynet.sendActivity(getActivity('',req));
    authorizeRequest(req, res, function(fromDevice){
      //TODO: Any server-to-server overriding should be done with ouath
      if(req.query.overrideIp && config.skynet_override_token && req.header('Skynet_override_token') == config.skynet_override_token){
        fromDevice.ipAddress = req.query.overrideIp;
      }else{
        fromDevice.ipAddress = req.connection.remoteAddress;
      }

      claimDevice(fromDevice, req.params, function(error, data){
        if(error){
          errorResponse(error, res);
        }else{
          res.json(data);
        }
      });
    });
  });


  // curl http://localhost:3000/gateway/01404680-2539-11e3-b45a-d3519872df26
  server.get('/gateway/:uuid', function(req, res){
    skynet.sendActivity(getActivity('',req));
    // res.setHeader('Access-Control-Allow-Origin','*');
    whoAmI(req.params.uuid, false, function(data){
      console.log(data);
      if(data.error){
        res.writeHead(302, {
          'location': 'http://skynet.im'
        });
      } else {
        res.writeHead(302, {
          'location': 'http://' + data.localhost + ":" + data.port
        });
      }
      res.end();

    });
  });


  // curl -X POST -d "name=arduino&description=this+is+a+test" http://localhost:3000/devices
  server.post('/devices', function(req, res){
    skynet.sendActivity(getActivity('',req));
    res.setHeader('Access-Control-Allow-Origin','*');
    req.params.ipAddress = req.connection.remoteAddress;
    register(req.params, function(data){
      console.log('register', data);
      if(data.error){
        errorResponse(data.error, res);
      } else {
        res.json(data);
      }
    });
  });

  // curl -X PUT -d "token=123&online=true&temp=hello&temp2=world" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
  // curl -X PUT -d "token=123&online=true&temp=hello&temp2=null" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
  // curl -X PUT -d "token=123&online=true&temp=hello&temp2=" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
  // curl -X PUT -d "token=123&myArray=[1,2,3]" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
  // curl -X PUT -d "token=123&myArray=4&action=push" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
  server.put('/devices/:uuid', function(req, res){
    skynet.sendActivity(getActivity('',req));
    authorizeRequest(req, res, function(fromDevice){
      updateFromClient(fromDevice, req.params, function(result){
        if(result.error){
          errorResponse(result.error, res);
        }else{
          res.json(result);
        }
      });
    });
  });

  // curl -X DELETE -d "token=123" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
  server.del('/devices/:uuid', function(req, res){
    skynet.sendActivity(getActivity('',req));
    authorizeRequest(req, res, function(fromDevice){
      unregister(fromDevice, req.params.uuid, function(err, data){
        console.log(err, data);
        // io.sockets.in(req.params.uuid).emit('message', data)
        if(err){
          errorResponse(err, res);
        } else {
          res.json(data);
        }
      });
    });

  });

  // Returns all devices owned by authenticated user
  // curl -X GET http://localhost:3000/mydevices/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc?token=qirqglm6yb1vpldixflopnux4phtcsor
  server.get('/mydevices', function(req, res){
    skynet.sendActivity(getActivity('',req));
    authorizeRequest(req, res, function(fromDevice){
      getDevices(fromDevice, {owner: fromDevice.uuid}, true, function(data){
          console.log(data);
          // io.sockets.in(req.params.uuid).emit('message', data)
          if(data.error){
            errorResponse(data.error, res);
          } else {
            res.json(data);
          }
        });
    });
  });


  // curl -X GET http://localhost:3000/events/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc?token=qirqglm6yb1vpldixflopnux4phtcsor
  server.get('/events/:uuid', function(req, res){
    skynet.sendActivity(getActivity('',req));
    authorizeRequest(req, res, function(fromDevice){
      logEvent(201, {fromUuid: fromDevice, uuid: req.params.uuid});
      getEvents(fromDevice.uuid, function(data){
          console.log(data);
          // io.sockets.in(req.params.uuid).emit('message', data)
          if(data.error){
            errorResponse(data.error, res);
          } else {
            res.json(data);
          }
        });
    });
  });

  // curl -X GET http://localhost:3000/events/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc?token=qirqglm6yb1vpldixflopnux4phtcsor
  server.get('/subscribe/:uuid', function(req, res){
    skynet.sendActivity(getActivity('',req));
    authorizeRequest(req, res, function(fromDevice){
        logEvent(204, {fromUuid: fromDevice, uuid: req.params.uuid});
        var foo = JSONStream.stringify(open='\n', sep=',\n', close='\n\n');
        foo.on("data", function(data){
          console.log(data);
          data = data + '\r\n';
        });
        subscribe(req.params.uuid)
          .pipe(foo)
          .pipe(res);
    });
  });

  // curl -X GET http://localhost:3000/authenticate/81246e80-29fd-11e3-9468-e5f892df566b?token=5ypy4rurayktke29ypbi30kcw5ovfgvi
  server.get('/authenticate/:uuid', function(req, res){
    skynet.sendActivity(getActivity('',req));
    res.setHeader('Access-Control-Allow-Origin','*');
    authDevice(req.params.uuid, req.query.token, function(auth){
      if (auth.authenticate){
        res.json({uuid:req.params.uuid, authentication: true});
      } else {
        var regdata = {
          "error": {
            "message": "Device not found or token not valid",
            "code": 404
          }
        };
        res.json(regdata.error.code, {uuid:req.params.uuid, authentication: false});

      }
    });
  });


  // curl -X POST -d '{"devices": "all", "payload": {"yellow":"off"}}' http://localhost:3000/messages
  // curl -X POST -d '{"devices": ["ad698900-2546-11e3-87fb-c560cb0ca47b","2f3113d0-2796-11e3-95ef-e3081976e170"], "payload": {"yellow":"off"}}' http://localhost:3000/messages
  // curl -X POST -d '{"devices": "ad698900-2546-11e3-87fb-c560cb0ca47b", "payload": {"yellow":"off"}}' http://localhost:3000/messages
  server.post('/messages', function(req, res, next){
    skynet.sendActivity(getActivity('',req));
    authorizeRequest(req, res, function(fromDevice){
      var body;
      try {
        body = JSON.parse(req.body);
      } catch(err) {
        body = req.body;
      }
      if (!body.devices){
        try {
          body = JSON.parse(req.params);
        } catch(err) {
          body = req.params;
        }
      }
      var devices = body.devices;
      var message = {};
      message.payload = body.payload;
      message.devices = body.devices;
      message.subdevice = body.subdevice;

      console.log('payload: ' + JSON.stringify(message));

      skynet.sendMessage(fromDevice, message);
      res.json({devices:devices, subdevice: body.subdevice, payload: body.payload});

      logEvent(300, message);
    });

  });

  // curl -X POST -d '{"uuid": "ad698900-2546-11e3-87fb-c560cb0ca47b", "token": "g6jmsla14j2fyldi7hqijbylwmrysyv5", "method": "getSubdevices"' http://localhost:3000/gatewayConfig
  server.post('/gatewayconfig', function(req, res, next){
    skynet.sendActivity(getActivity('',req));
    authorizeRequest(req, res, function(fromDevice){
      var body;
      try {
        body = JSON.parse(req.body);
      } catch(err) {
        console.log('error parsing', err, req.body);
        body = {};
      }

      skynet.gatewayConfig(body, function(result){
        if(result && result.error){
          errorResponse(result.error, res);
        }else{
          res.json(result);
        }
      });

      logEvent(300, body);
    });
  });

  // curl -X GET -d "token=123" http://localhost:3000/inboundsms
  server.get('/inboundsms', function(req, res){
    skynet.sendActivity(getActivity('',req));

    res.setHeader('Access-Control-Allow-Origin','*');
    console.log(req.params);
    // { To: '17144625921',
    // Type: 'sms',
    // MessageUUID: 'f1f3cc84-8770-11e3-9f8a-842b2b455655',
    // From: '14803813574',
    // Text: 'Test' }
    var data;
    try{
      data = JSON.parse(req.params);
    } catch(e){
      data = req.params;
    }
    var toPhone = data.To;
    var fromPhone = data.From;
    var message = data.Text;

    getPhone(toPhone, function(err, phoneDevice){
      var eventData = {devices: phoneDevice, payload: message};
      if(err){
        err.code = 404;
        eventData.error = err;
      }
      else{
        var msg = {
              devices: "*",
              payload: message,
              api: 'message',
              fromUuid: phoneDevice.uuid,
              eventCode: 300,
              fromPhone: fromPhone,
              sms: true
            };

        skynet.sendMessage(phoneDevice, msg);
      }

      logEvent(301, eventData);
      if(eventData.error){
        errorResponse(eventData.error, res);
      } else {
        res.json(eventData);
      }

    });
  });

  // curl -X POST -d "token=123&temperature=78" http://localhost:3000/data/ad698900-2546-11e3-87fb-c560cb0ca47b
  server.post('/data/:uuid', function(req, res){
    skynet.sendActivity(getActivity('',req));
    authorizeRequest(req, res, function(fromDevice){

      delete req.params.token;

      req.params.ipAddress = req.connection.remoteAddress;
      logData(req.params, function(data){
        console.log(data);
        // io.sockets.in(data.uuid).emit('message', data)
        if(data.error){
          errorResponse(data.error, res);
        } else {

          // Send messsage regarding data update
          var message = {};
          message.payload = req.params;
          // message.devices = req.params.uuid;
          message.devices = "*";

          console.log('message: ' + JSON.stringify(message));

          skynet.sendMessage(fromDevice, message);

          res.json(data);
        }
      });
    });

  });

  // curl -X GET http://localhost:3000/data/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc?token=qirqglm6yb1vpldixflopnux4phtcsor
  server.get('/data/:uuid', function(req, res){
    skynet.sendActivity(getActivity('',req));
    authorizeRequest(req, res, function(fromDevice){
      if(req.query.stream){

        var foo = JSONStream.stringify(open='\n', sep=',\n', close='\n\n');
        foo.on("data", function(data){
          // data = data.toString() + '\r\n';
          console.log('DATA', data);
          return data;
        });
        getData(req)
          .pipe(foo)
          .pipe(res);

      } else {

        getData(req, function(data){
          console.log(data);
          if(data.error){
            errorResponse(data.error, res);
          } else {
            res.json(data);
          }
        });
      }
    });
  });


  // Serve static website
  var file = new nstatic.Server('');
  server.get('/demo/:uuid', function(req, res, next) {
    skynet.sendActivity(getActivity('',req));
    file.serveFile('/demo.html', 200, {}, req, res);
  });

  server.get('/', function(req, res, next) {
    skynet.sendActivity(getActivity('',req));
    file.serveFile('/index.html', 200, {}, req, res);
  });

  server.get(/^\/.*/, function(req, res, next) {
    file.serve(req, res, next);
  });

  return server;

}

module.exports = setupHttpRoutes;
