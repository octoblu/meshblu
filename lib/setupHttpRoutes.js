var nstatic = require('node-static');

var config = require('../config');

var getYo  = require('./getYo');
var whoAmI = require('./whoAmI');
var getData = require('./getData');
var logData = require('./logData');
var logEvent = require('./logEvent');
var getPhone  = require('./getPhone');
var register = require('./register');
// var getEvents = require('./getEvents');
var subEvents = require('./subEvents');
var resetToken = require('./resetToken');
var getDevices = require('./getDevices');
var authDevice = require('./authDevice');
var unregister = require('./unregister');
var claimDevice = require('./claimDevice');
var getPublicKey = require('./getPublicKey');
var securityImpl = require('./getSecurityImpl');
var createActivity = require('./createActivity');
var getLocalDevices = require('./getLocalDevices');
var getSystemStatus = require('./getSystemStatus');
var updateFromClient = require('./updateFromClient');
var createReadStream = require('./createReadStream');

function getIP(req){
  return req.headers["x-forwarded-for"] || req.connection.remoteAddress;
}

function getActivity(topic, req, device, toDevice){
  return createActivity(topic, getIP(req), device, toDevice);
}

//psuedo middleware
function authorizeRequest(req, res, next){
  var authUuid, authToken;
  if(req.header('skynet_auth_uuid') && req.header('skynet_auth_token')){
    authUuid = req.header('skynet_auth_uuid');
    authToken = req.header('skynet_auth_token');
  } else {
    authUuid = req.header('meshblu_auth_uuid');
    authToken = req.header('meshblu_auth_token');
  }


  authDevice(authUuid, authToken, function (error, device) {   
    if(!device){
      return res.json(401, {error: 'unauthorized'});
    }

    return next(device);
  });
}

function errorResponse(error, res){
  if(error.code){
    res.json(error.code, error);
  }else{
    res.json(400, error);
  }
}

function streamMessages(req, res, topic){
  res.setHeader('Connection','keep-alive');
  var rs = createReadStream();

  var subHandler = function(topic, msg){
    rs.pushMsg(msg);
  };

  subEvents.on(topic, subHandler);

  rs.pipe(res);

  res.once('close', function(a){
    subEvents.removeListener(topic, subHandler);
  });
}

function subscribeBroadcast(req, res, type, skynet){
  authorizeRequest(req, res, function(fromDevice){
    skynet.sendActivity(getActivity(type,req, fromDevice));
    var uuid = req.params.uuid;
    logEvent(204, {fromUuid: fromDevice.uuid, from: fromDevice, uuid: uuid});
    if(uuid && uuid.length > 30){
      //no token provided, attempt to only listen for public broadcasts FROM this uuid
      whoAmI(req.params.uuid, false, function(results){
        if(results.error){
          errorResponse(results.error, res);
        }else{
          if(securityImpl.canReceive(fromDevice, results)){
            streamMessages(req, res, uuid + '_bc');
          }else{
            errorResponse({error: "unauthorized access"}, res);
          }
        }
      });
    }
  });
}

function setupHttpRoutes(server, skynet){

    // curl http://localhost:3000/status
  server.get('/status', function(req, res){
    skynet.sendActivity(getActivity('status',req));
    res.setHeader('Access-Control-Allow-Origin','*');
    getSystemStatus(function(data){
      if(data.error){
        errorResponse(data.error, res);
      } else {
        res.json(data);
      }

    });
  });

  // curl http://localhost:3000/ipaddress
  server.get('/ipaddress', function(req, res){
    skynet.sendActivity(getActivity('ipaddress',req));
    res.setHeader('Access-Control-Allow-Origin','*');
    res.json({ipAddress: getIP(req)});
  });

  // curl http://localhost:3000/devices
  // curl http://localhost:3000/devices?key=123
  // curl http://localhost:3000/devices?online=true
  // server.get('/devices/:uuid', function(req, res){
  server.get('/devices', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('devices',req, fromDevice));
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
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('devices',req, fromDevice));
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
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('localdevices',req, fromDevice));
      if(req.query.overrideIp && config.skynet_override_token && req.header('Skynet_override_token') === config.skynet_override_token){
        fromDevice.ipAddress = req.query.overrideIp;
      }else{
        fromDevice.ipAddress = getIP(req);
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

  server.get('/unclaimeddevices', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('localdevices',req, fromDevice));
      if(req.query.overrideIp && config.skynet_override_token && req.header('Skynet_override_token') === config.skynet_override_token){
        fromDevice.ipAddress = req.query.overrideIp;
      }else{
        fromDevice.ipAddress = getIP(req);
      }

      getLocalDevices(fromDevice, true, function(data){
        if(data.error){
          errorResponse(data.error, res);
        }else{
          res.json(data);
        }
      });
    });

  });

  server.put('/claimdevice/:uuid', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('claimdevice',req, fromDevice));
      //TODO: Any server-to-server overriding should be done with ouath
      if(req.query.overrideIp && config.skynet_override_token && req.header('Skynet_override_token') === config.skynet_override_token){
        fromDevice.ipAddress = req.query.overrideIp;
      }else{
        fromDevice.ipAddress = getIP(req);
      }

      claimDevice(fromDevice, req.params, function(error, data){
        if(error){
          res.json(400, error.msg);
        }else{
          res.json(data);
        }
      });
    });
  });

  server.get('/devices/:uuid/publickey', function(req, res){
    getPublicKey(req.params.uuid, function(error, publicKey){
      if(error){
        return res.send(500, {error: error.message});
      }

      res.json({publicKey: publicKey});
    });
  });

  // curl -X POST http://localhost:3000/devices/:uuid/token
  server.post('/devices/:uuid/token', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('resetToken',req, fromDevice));          
      resetToken(fromDevice, req.params.uuid, function(error,token){
        if(error){
          errorResponse(error, res);
        }else{
          skynet.sendConfigActivity(req.params.uuid || fromDevice.uuid, skynet.emitToClient);
          res.json(token);
        }
      });
    });
  });


  // curl -X POST -d "name=arduino&description=this+is+a+test" http://localhost:3000/devices
  server.post('/devices', function(req, res){
    skynet.sendActivity(getActivity('devices',req));
    res.setHeader('Access-Control-Allow-Origin','*');
    req.params.ipAddress = getIP(req);

    register(req.params, function(error, device){
      if(error){
        return res.send(500, error.msg);
      }

      res.json(201, device);
    });
  });

  // curl -X POST -d "name=arduino&description=this+is+a+test" http://localhost:3000/devices/micro
  server.post('/devices/micro', function(req, res){
    skynet.sendActivity(getActivity('devices/micro',req));
    req.params.ipAddress = getIP(req);
    res.contentType = 'text';

    register(req.params, function(error, device){
      if(error) {
        return res.send(400, null);
      }

      return res.send(200, device.uuid + '\n' + device.token);
    });
  });

  // curl -X PUT -d "token=123&online=true&temp=hello&temp2=world" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
  // curl -X PUT -d "token=123&online=true&temp=hello&temp2=null" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
  // curl -X PUT -d "token=123&online=true&temp=hello&temp2=" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
  // curl -X PUT -d "token=123&myArray=[1,2,3]" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
  // curl -X PUT -d "token=123&myArray=4&action=push" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
  server.put('/devices/:uuid', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('devices',req, fromDevice));
      updateFromClient(fromDevice, req.params, function(result){
        if(result.error){
          errorResponse(result.error, res);
        }else{
          skynet.sendConfigActivity(req.params.uuid || fromDevice.uuid, skynet.emitToClient);
          res.json(result);
        }
      });
    });
  });

  // curl -X DELETE -d "token=123" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
  server.del('/devices/:uuid', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('unregister',req, fromDevice));
      unregister(fromDevice, req.params.uuid, req.params.token, skynet.emitToClient, function(err, data){
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
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('mydevices',req, fromDevice));
      getDevices(fromDevice, {owner: fromDevice.uuid}, true, function(data){
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
    res.send(401);
    // authorizeRequest(req, res, function(fromDevice){
    //   skynet.sendActivity(getActivity('events',req, fromDevice));
    //   logEvent(201, {fromUuid: fromDevice.uuid, from: fromDevice, uuid: req.params.uuid});
    //   getEvents(fromDevice.uuid, function(data){
    //       if(data.error){
    //         errorResponse(data.error, res);
    //       } else {
    //         res.json(data);
    //       }
    //     });
    // });
  });

  // curl -X GET http://localhost:3000/subscribe/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc
  server.get('/subscribe/:uuid', function(req, res){
    subscribeBroadcast(req, res, 'subscribe', skynet);
  });

  // curl -X GET http://localhost:3000/subscribe
  server.get('/subscribe', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('subscribe',req, fromDevice));
      //var uuid = req.params.uuid;
      logEvent(204, {fromUuid: fromDevice.uuid, from: fromDevice});
      streamMessages(req, res, fromDevice.uuid );
    });
  });

  // curl -X GET http://localhost:3000/authenticate/81246e80-29fd-11e3-9468-e5f892df566b?token=5ypy4rurayktke29ypbi30kcw5ovfgvi
  server.get('/authenticate/:uuid', function(req, res){
    skynet.sendActivity(getActivity('authenticate',req));
    res.setHeader('Access-Control-Allow-Origin','*');
    authDevice(req.params.uuid, req.query.token, function(error, device){
      if (!device) {
        var regdata = {
          "error": {
            "message": "Device not found or token not valid",
            "code": 404
          }
        };
        return res.json(regdata.error.code, {uuid:req.params.uuid, authentication: false});
      }

      res.json({uuid:req.params.uuid, authentication: true});
    });
  });


  // curl -X POST -d '{"devices": "all", "payload": {"yellow":"off"}}' http://localhost:3000/messages
  // curl -X POST -d '{"devices": ["ad698900-2546-11e3-87fb-c560cb0ca47b","2f3113d0-2796-11e3-95ef-e3081976e170"], "payload": {"yellow":"off"}}' http://localhost:3000/messages
  // curl -X POST -d '{"devices": "ad698900-2546-11e3-87fb-c560cb0ca47b", "payload": {"yellow":"off"}}' http://localhost:3000/messages
  server.post('/messages', function(req, res, next){

    authorizeRequest(req, res, function(fromDevice){
      //skynet.sendActivity(getActivity('messages',req));
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
      message.devices = body.devices;
      message.subdevice = body.subdevice;
      message.topic = body.topic;
      message.payload = body.payload;

      skynet.sendMessage(fromDevice, message);
      res.json({devices:devices, subdevice: body.subdevice, payload: body.payload});

      logEvent(300, message);
    });

  });

  // Inbound SMS
  // curl -X GET -d "token=123" http://localhost:3000/inboundsms
  server.get('/inboundsms', function(req, res){
    skynet.sendActivity(getActivity('inboundsms',req));

    res.setHeader('Access-Control-Allow-Origin','*');
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

  // Inbound Yo
  // curl -X GET "http://localhost:3000/inboundyo?username=christoffe"
  server.get('/inboundyo', function(req, res){
    skynet.sendActivity(getActivity('inboundyo',req));

    res.setHeader('Access-Control-Allow-Origin','*');
    var yoUsername = req.params.username;

    getYo(yoUsername, function(err, yoDevice){
      var eventData = {devices: yoDevice, payload: "yo"};
      if(err){
        err.code = 404;
        eventData.error = err;
      }
      else{
        var msg = {
              devices: "*",
              payload: "yo",
              api: 'message',
              fromUuid: yoDevice.uuid,
              eventCode: 300,
              fromPhone: yoUsername,
              yo: true
            };

        skynet.sendMessage(yoDevice, msg);
      }

      logEvent(303, eventData);
      if(eventData.error){
        errorResponse(eventData.error, res);
      } else {
        res.json(eventData);
      }

    });
  });


  // curl -X POST -d "token=123&temperature=78" http://localhost:3000/data/ad698900-2546-11e3-87fb-c560cb0ca47b
  server.post('/data/:uuid', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('data',req, fromDevice));
      delete req.params.token;

      req.params.ipAddress = getIP(req);
      logData(req.params, function(data){
        if(data.error){
          errorResponse(data.error, res);
        } else {

          // Send messsage regarding data update
          var message = {};
          message.payload = req.params;
          // message.devices = req.params.uuid;
          message.devices = "*";

          skynet.sendMessage(fromDevice, message);

          res.json(data);
        }
      });
    });

  });

  // curl -X GET http://localhost:3000/data/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc?token=qirqglm6yb1vpldixflopnux4phtcsor
  server.get('/data/:uuid', function(req, res){
    if(req.query.stream){
      subscribeBroadcast(req, res, 'data', skynet);
    }
    else{
      authorizeRequest(req, res, function(fromDevice){
        skynet.sendActivity(getActivity('data',req, fromDevice));
        getData(req, function(data){
          if(data.error){
            errorResponse(data.error, res);
          } else {
            res.json(data);
          }
        });
      });
    }

  });


  // Serve static website
  var file = new nstatic.Server('./public');

  server.get('/localjsconsole', function(req, res, next) {
    skynet.sendActivity(getActivity('localjsconsole',req));
    file.serveFile('/localjsconsole.html', 200, {}, req, res);
  });

  server.get('/', function(req, res, next) {
    skynet.sendActivity(getActivity('website',req));
    file.serveFile('/index.html', 200, {}, req, res);
  });

  server.get(/^\/.*/, function(req, res, next) {
    file.serve(req, res, next);
  });

  return server;
}

module.exports = setupHttpRoutes;
