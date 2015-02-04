var JSONStream = require('JSONStream');

var whoAmI = require('./whoAmI');
var getData = require('./getData');
var logData = require('./logData');
var logEvent = require('./logEvent');
var register = require('./register');
var getEvents = require('./getEvents');
var subEvents = require('./subEvents');
var getDevices = require('./getDevices');
var authDevice = require('./authDevice');
var unregister = require('./unregister');
var resetToken = require('./resetToken');
var getPublicKey = require('./getPublicKey');
var securityImpl = require('./getSecurityImpl');
var createActivity = require('./createActivity');
var getSystemStatus = require('./getSystemStatus');
var updateFromClient = require('./updateFromClient');
var createReadStream = require('./createReadStream');
var _ = require('lodash');

function getActivity(topic, req, device, toDevice){
  var ip = req.rsinfo.address;
  return createActivity(topic, ip, device, toDevice);
}

//psuedo middleware
function authorizeRequest(req, res, next){
  var uuid = _.find(req.options, {name:'98'});
  var token = _.find(req.options, {name:'99'});
  if (uuid && uuid.value) {
    uuid = uuid.value.toString();
  }
  if (token && token.value) {
    token = token.value.toString();
  }

  authDevice(uuid, token, function (error, device) {
    if(!device){
      return res.json(401, {error: 'unauthorized'});
    }

    return next(device);
  });
}

function errorResponse(error, res){
  if(error.code){
    res.statusCode = error.code;
    res.json(error);
  }else{
    res.statusCode = 400;
    res.json(400, error);
  }
}

function streamMessages(req, res, topic){
  var rs = createReadStream();
  var subHandler = function(topic, msg){
    rs.pushMsg(JSON.stringify(msg));
  };

  subEvents.on(topic, subHandler);
  rs.pipe(res);

  //functionas a heartbeat.
  //If client stops responding, we can assume disconnected and cleanup
  var interval = setInterval(function() {
    res.write('');
  }, 10000);

  res.once('finish', function(err) {
    clearInterval(interval);
    subEvents.removeListener(topic, subHandler);
  });

}

function subscribeBroadcast(req, res, type, skynet){
  authorizeRequest(req, res, function(fromDevice){
    skynet.sendActivity(getActivity(type, req, fromDevice));
    var uuid = req.params.uuid;
    logEvent(204, {fromUuid: fromDevice, uuid: uuid});
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


function setupCoapRoutes(coapRouter, skynet){

  // coap get coap://localhost/status
  coapRouter.get('/status', function (req, res) {
    skynet.sendActivity(getActivity('status', req));

    getSystemStatus(function (data) {
      if(data.error) {
        res.statusCode = data.error.code;
        res.json(data.error);
      } else {
        res.statusCode = 200;
        res.json(data);
      }
    });
  });


  // coap get coap://localhost/ipaddress
  coapRouter.get('/ipaddress', function (req, res) {
    skynet.sendActivity(getActivity('ipaddress', req));
    res.json({ipAddress: req.rsinfo.address});
  });

  coapRouter.get('/devices', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('devices', req, fromDevice));

      getDevices(fromDevice, req.query, false, function(data){
        if(data.error){
          errorResponse(data.error, res);
        }else{
          res.json(data);
        }
      });
    });
  });

  coapRouter.post('/devices', function (req, res) {
    skynet.sendActivity(getActivity('devices', req));

    req.params.ipAddress = req.rsinfo.address;
    register(req.params, function (error, data) {
      if(error) {
        res.statusCode = 500;
        return res.json(error.msg);
      }

      res.statusCode = 201;
      res.json(data);
    });
  });

  // coap get coap://localhost/devices/a1634681-cb10-11e3-8fa5-2726ddcf5e29
  coapRouter.get('/devices/:uuid', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('devices', req, fromDevice));
      getDevices(fromDevice, {uuid: req.params.uuid}, false, function(data){
          if(data.error){
            errorResponse(data.error, res);
          }else{
            res.json(data);
          }
        });
    });
  });


  coapRouter.put('/devices/:uuid', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('devices', req, fromDevice));
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

  coapRouter.delete('/devices/:uuid', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('unregister', req, fromDevice));
      unregister(fromDevice, req.params.uuid, req.params.token, skynet.emitToClient, function(err, data){
        if(err){
          errorResponse(err, res);
        } else {
          res.json(data);
        }
      });
    });

  });

  coapRouter.get('/devices/:uuid/publickey', function(req, res){
    getPublicKey(req.params.uuid, function(error, publicKey){
      if(error){
        return res.send(500, {error: error.message});
      }

      res.json({publicKey: publicKey});
    });
  });

  // coap post coap://localhost:3000/devices/:uuid/token
  coapRouter.post('/devices/:uuid/token', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('resetToken', req, fromDevice));
      resetToken(req.params.uuid, fromDevice, function(err,token){
        if(err){
          errorResponse(err, res);
        } else {
          res.json({uuid: req.params.uuid, token: token});
        }
      });
    });
  });

  coapRouter.get('/mydevices', function (req, res) {
     authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('mydevices', req, fromDevice));
      authDevices(fromDevice, {owner: fromDevice.uuid}, true, function(data){
        if(data.error){
          errorResponse(data.error, res);
        } else {
          res.json(data);
        }
      });
    });
  });

  coapRouter.post('/gatewayConfig', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('gatewayConfig', req, fromDevice));
      var body;
      try {
        body = JSON.parse(req.body);
      } catch(err) {
        console.error('error parsing', err, req.body);
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

  // coap get coap://localhost/events/196798f1-b5d8-11e3-8c93-45a0c0308eaa -p "token=00cpk8akrmz8semisbebhe0358livn29"
  coapRouter.get('/events/:uuid', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('events', req, fromDevice));
      logEvent(201, {fromUuid: fromDevice.uuid, from: fromDevice, uuid: req.params.uuid});
      getEvents(fromDevice.uuid, function(data){
        if(data.error){
          errorResponse(data.error, res);
        } else {
          res.json(data);
        }
      });
    });


  });


  // coap post coap://localhost/data/196798f1-b5d8-11e3-8c93-45a0c0308eaa -p "token=00cpk8akrmz8semisbebhe0358livn29&temperature=43"
  coapRouter.post('/data/:uuid', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('data', req, fromDevice));
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

  // coap get coap://localhost/data/196798f1-b5d8-11e3-8c93-45a0c0308eaa -p "token=00cpk8akrmz8semisbebhe0358livn29&limit=1"
  coapRouter.get('/data/:uuid', function(req, res){
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

  // coap post coap://localhost/messages -p "devices=a1634681-cb10-11e3-8fa5-2726ddcf5e29&payload=test"
  coapRouter.post('/messages', function (req, res, next) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('messages', req, fromDevice));
      var body;
      try {
        body = JSON.parse(req.params);
      } catch(err) {
        body = req.params;
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
      message.topic = body.topic;

      skynet.sendMessage(fromDevice, message);
      res.json({devices:devices, subdevice: body.subdevice, payload: body.payload});

      logEvent(300, message);
    });
  });

  coapRouter.get('/subscribe', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('subscribe', req, fromDevice));
      logEvent(204, {fromUuid: fromDevice.uuid, from: fromDevice, uuid: req.params.uuid});
      streamMessages(req, res, fromDevice.uuid);
    });
  });

  coapRouter.get('/subscribe/:uuid', function (req, res) {
    subscribeBroadcast(req, res, 'subscribe', skynet);
  });
}

module.exports = setupCoapRoutes;
