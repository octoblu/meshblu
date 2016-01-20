var _ = require('lodash');
var config = require('../config');
var getYo  = require('./getYo');
var whoAmI = require('./whoAmI');
var getData = require('./getData');
var logData = require('./logData');
var logEvent = require('./logEvent');
var getPhone  = require('./getPhone');
var register = require('./register');
var resetToken = require('./resetToken');
var getDevices = require('./getDevices');
var authDevice = require('./authDevice');
var getDevice = require('./getDevice');
var unregister = require('./unregister');
var claimDevice = require('./claimDevice');
var getPublicKey = require('./getPublicKey');
var securityImpl = require('./getSecurityImpl');
var createActivity = require('./createActivity');
var getSystemStatus = require('./getSystemStatus');
var updateFromClient = require('./updateFromClient');
var createReadStream = require('./createReadStream');
var updateIfAuthorized = require('./updateIfAuthorized');
var generateAndStoreToken = require('./generateAndStoreToken');
var revokeToken = require('./revokeToken');
var debug = require('debug')('meshblu:protocol:setupHttpRoutes');
var SocketIOClient = require('socket.io-client');
var MeshbluEventEmitter = require('./MeshbluEventEmitter');
var Readable = require('stream').Readable;
var subscribeAndForward = require('./subscribeAndForward');
var saveDataIfAuthorized = require('./saveDataIfAuthorized');
var createSubscriptionIfAuthorized = require('./createSubscriptionIfAuthorized');
var deleteSubscriptionIfAuthorized = require('./deleteSubscriptionIfAuthorized');

function getIP(req){
  return req.headers["x-forwarded-for"] || req.connection.remoteAddress;
}

function getActivity(topic, req, device, toDevice){
  return createActivity(topic, getIP(req), device, toDevice);
}

function getAuthUuidAndToken(req) {
  var authUuid, authToken;

  if (req.headers.authorization) {
    var parts = req.headers.authorization.split(' ');
    var scheme = parts[0]
    var encodedToken = parts[1]
    if (encodedToken === undefined) {
      return {}
    }
    var token = new Buffer(encodedToken, 'base64').toString().split(':')
    authUuid = token[0]
    authToken = token[1]
  }

  if(req.header('skynet_auth_uuid') && req.header('skynet_auth_token')){
    authUuid = req.header('skynet_auth_uuid');
    authToken = req.header('skynet_auth_token');
  }

  if (req.header('meshblu_auth_uuid') && req.header('meshblu_auth_token')){
    authUuid = req.header('meshblu_auth_uuid');
    authToken = req.header('meshblu_auth_token');
  }

  if (req.header('X-Meshblu-UUID') && req.header('X-Meshblu-Token')){
    authUuid = req.header('X-Meshblu-UUID');
    authToken = req.header('X-Meshblu-Token');
  }

  if (authUuid) {
    authUuid = authUuid.trim();
  }

  if (authToken) {
    authToken = authToken.trim();
  }

  return {uuid: authUuid, token: authToken}
}


function getAuthDeviceFromRequest(req, callback) {
  var result = getAuthUuidAndToken(req);
  if (!result.uuid && !result.token) {
    return callback(new Error('unauthorized'));
  }
  authDevice(result.uuid, result.token, callback);
}

function errorResponse(error, res){
  debug('errorResponse', error.stack || error.message || error);
  if(error.code){
    res.status(error.code).send(error);
  }else{
    res.status(400).send(error);
  }
}

function setupHttpRoutes(server, skynet){
  var meshbluEventEmitter = new MeshbluEventEmitter(config.uuid, config.forwardEventUuids, skynet.sendMessage);

  //psuedo middleware
  function authorizeRequest(req, res, next){
    var result = getAuthUuidAndToken(req);
    if (!result.uuid && !result.token) {
      return res.status(401).send({error: 'unauthorized'});
    }

    authDevice(result.uuid, result.token, function (error, device) {
      if(!device){
        if (error) {
          debug('authDevice error', result.uuid, error.stack);
        }
        error = error || new Error('unauthorized');
        meshbluEventEmitter.emit('identity-error', {error: error.message, request: {uuid: getAuthUuidAndToken(req).uuid}});
        return res.status(401).send({error: error.message});
      }

      return next(device);
    });
  }

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

  server.get('/publickey', function(req, res){
    res.json({publicKey: config.publicKey});
  });

  server.get('/devices', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('devices',req, fromDevice));
      getDevices(fromDevice, req.query, false, function(error, data){
          if(error) {
            debug('GET /devices error', error.stack);
            return res.sendStatus(500);
          }

          if(data.error){
            var message = data.error.message || data.error;
            meshbluEventEmitter.emit('devices-error', {request: req.query, error: message, fromUuid: fromDevice.uuid});
            return errorResponse(data.error, res);
          }

          meshbluEventEmitter.emit('devices', {request: req.query, fromUuid: fromDevice.uuid});
          res.json(data);
        });
    });
  });

  server.get('/devices/:uuid', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('devices',req, fromDevice));
      getDevices(fromDevice, {uuid: req.params.uuid}, false, function(error, data){
          if(data.error){
            var message = data.error.message || data.error;
            meshbluEventEmitter.emit('devices-error', {request: {uuid: req.params.uuid}, error: message, fromUuid: fromDevice.uuid});
            return errorResponse(data.error, res);
          }

          meshbluEventEmitter.emit('devices', {request: {uuid: req.params.uuid}, fromUuid: fromDevice.uuid});
          res.json(data);
      });
    });
  });

  server.get('/v2/whoami', function(req, res){
    getAuthDeviceFromRequest(req, function(error, fromDevice) {
      if (error) {
        debug('GET /v2/whoami auth error', error.stack);
        meshbluEventEmitter.emit('identity-error', {error: error.message, request: {uuid: getAuthUuidAndToken(req).uuid}});
        return res.status(401).send({error: 'unauthorized'});
      }
      skynet.sendActivity(getActivity('whoami', req, fromDevice));
      meshbluEventEmitter.emit('whoami', {request: {}, fromUuid: fromDevice.uuid});
      res.json(fromDevice);
    });
  });


  server.get('/v2/devices', function(req, res){
    getAuthDeviceFromRequest(req, function(error, fromDevice) {
      if (error) {
        debug('/v2/devices auth error', error.stack);
        meshbluEventEmitter.emit('identity-error', {error: error.message, request: {uuid: getAuthUuidAndToken(req).uuid}});
        return res.status(401).send({error: 'unauthorized'});
      }

      getDevices(fromDevice, req.query, false, function(error, data){
        if(data.error && data.error.message !== "Devices not found"){
          var message = data.error.message || data.error;
          meshbluEventEmitter.emit('devices-error', {request: req.query, error: message, fromUuid: fromDevice.uuid});
          return errorResponse(data.error, res);
        }

        meshbluEventEmitter.emit('devices', {request: req.query, fromUuid: fromDevice.uuid});
        res.json(data.devices || []);
      });
    });
  });

  server.get('/v2/devices/:uuid', function(req, res){
    getAuthDeviceFromRequest(req, function(error, fromDevice) {
      if (error) {
        debug('GET /v2/devices/:uuid auth error', error.stack);
        meshbluEventEmitter.emit('identity-error', {error: error.message, request: {uuid: getAuthUuidAndToken(req).uuid}});
        return res.status(401).send({error: 'unauthorized'});
      }
      fromDevice = fromDevice || {};
      skynet.sendActivity(getActivity('device', req, fromDevice));
      getDevices(fromDevice, {uuid: req.params.uuid}, false, function(error, data){
          if(data.error){
            var message = data.error.message || data.error;
            meshbluEventEmitter.emit('devices-error', {request: {uuid: req.params.uuid}, error: message, fromUuid: fromDevice.uuid});
            return errorResponse(data.error, res);
          }

          meshbluEventEmitter.emit('devices', {request: {uuid: req.params.uuid}, fromUuid: fromDevice.uuid});
          res.json(_.first(data.devices));
        });
    });
  });

  server.patch('/v2/devices/:uuid', function(req, res){
    getAuthDeviceFromRequest(req, function(error, fromDevice) {
      if (error) {
        debug('PATCH /v2/devices/:uuid auth error', error.stack);
        meshbluEventEmitter.emit('identity-error', {error: error.message, request: {uuid: getAuthUuidAndToken(req).uuid}});
        return res.status(401).send({error: 'unauthorized'});
      }

      updateIfAuthorized(fromDevice, {uuid: req.params.uuid}, {$set: req.body}, function(error){
        var requestLog = {params: {$set: req.body}, query: {uuid: req.params.uuid}};
        if(error){
          meshbluEventEmitter.emit('update-error', {error: error.message, request: requestLog, fromUuid: fromDevice.uuid});
          return res.status(422).send({error: error.message});
        }
        meshbluEventEmitter.emit('update', {request: requestLog, fromUuid: fromDevice.uuid});
        return res.status(204).send();
      });
    });
  });

  server.put('/v2/devices/:uuid', function(req, res){
    getAuthDeviceFromRequest(req, function(error, fromDevice) {
      if (error) {
        debug('PUT /v2/devices/:uuid auth error', error.stack);
        meshbluEventEmitter.emit('identity-error', {error: error.message, request: {uuid: getAuthUuidAndToken(req).uuid}});
        return res.status(401).send({error: 'unauthorized'});
      }

      var forwardedFor = [];
      if(req.header('x-meshblu-forwardedfor')){
        forwardedFor = JSON.parse(req.header('x-meshblu-forwardedfor'));
      }

      updateIfAuthorized(fromDevice, {uuid: req.params.uuid}, req.body, {forwardedFor: forwardedFor}, function(error){
        var requestLog = {params: req.body, query: {uuid: req.params.uuid}};
        if(error){
          meshbluEventEmitter.emit('update-error', {error: error.message, request: requestLog, fromUuid: fromDevice.uuid});
          return res.status(422).send({error: error.message});
        }

        meshbluEventEmitter.emit('update', {request: requestLog, fromUuid: fromDevice.uuid});
        return res.status(204).send();
      });
    });
  });

  server.post('/v2/devices/:subscriberUuid/subscriptions/:emitterUuid/:type', function(req, res){
    getAuthDeviceFromRequest(req, function(error, fromDevice) {
      if (error) {
        debug('POST /v2/devices/:subscriberUuid/subscriptions/:emitterUuid/:type auth error', error.stack);
        meshbluEventEmitter.emit('identity-error', {error: error.message, request: {uuid: getAuthUuidAndToken(req).uuid}});
        return res.status(401).send({error: 'unauthorized'});
      }

      createSubscriptionIfAuthorized(fromDevice, req.params, function(error){
        if(error){
          meshbluEventEmitter.emit('subscribe-error', {error: error.message, request: req.params, fromUuid: fromDevice.uuid});
          return res.status(422).send({error: error.message});
        }

        meshbluEventEmitter.emit('subscribe', {request: req.params, fromUuid: fromDevice.uuid});
        return res.status(204).send();
      });
    });
  });

  server.delete('/v2/devices/:uuid/subscriptions/:targetUuid/:type', function(req, res){
    getAuthDeviceFromRequest(req, function(error, fromDevice) {
      if (error) {
        debug('DELETE /v2/devices/:uuid/subscriptions/:targetUuid/:type auth error', error.stack);
        meshbluEventEmitter.emit('identity-error', {error: error.message, request: {uuid: getAuthUuidAndToken(req).uuid}});
        return res.status(401).send({error: 'unauthorized'});
      }

      deleteSubscriptionIfAuthorized(fromDevice, req.params, function(error){
        if(error){
          meshbluEventEmitter.emit('unsubscribe-error', {error: error.message, request: req.params, fromUuid: fromDevice.uuid});
          return res.status(422).send({error: error.message});
        }

        meshbluEventEmitter.emit('unsubscribe', {request: req.params, fromUuid: fromDevice.uuid});
        return res.status(204).send();
      });
    });
  });

  server.put('/claimdevice/:uuid', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('claimdevice',req, fromDevice));

      if(req.query.overrideIp && config.skynet_override_token && req.header('Skynet_override_token') === config.skynet_override_token){
        fromDevice.ipAddress = req.query.overrideIp;
      }else{
        fromDevice.ipAddress = getIP(req);
      }

      claimDevice(fromDevice, {uuid: req.params.uuid}, function(error, data){
        if(error){
          meshbluEventEmitter.emit('claimdevice-error', {request: {uuid: req.params.uuid}, error: error.message, fromUuid: fromDevice.uuid, fromIp: fromDevice.ipAddress});
          return res.status(400).send({error: error.message});
        }

        meshbluEventEmitter.emit('claimdevice', {request: {uuid: req.params.uuid}, fromUuid: fromDevice.uuid, fromIp: fromDevice.ipAddress});
        res.json(data);
      });
    });
  });

  server.get('/devices/:uuid/publickey', function(req, res){
    getPublicKey(req.params.uuid, function(error, publicKey){
      if(error){
        meshbluEventEmitter.emit('getpublickey-error', {request: {uuid: req.params.uuid}, error: error.message});
        return res.status(500).send({error: error.message});
      }

      meshbluEventEmitter.emit('getpublickey', {request: {uuid: req.params.uuid}});
      res.json({publicKey: publicKey});
    });
  });

  server.post('/devices/:uuid/token', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('resetToken',req, fromDevice));
      resetToken(fromDevice, req.params.uuid, skynet.emitToClient, function(error,token){
        if(error){
          // This error is a string, not Error object
          meshbluEventEmitter.emit('resettoken-error', {request: {uuid: req.params.uuid}, error: error, fromUuid: fromDevice.uuid});
          return errorResponse(error, res);
        }

        var uuid = req.params.uuid || fromDevice.uuid;
        meshbluEventEmitter.emit('resettoken', {request: {uuid: req.params.uuid}, fromUuid: fromDevice.uuid});
        res.status(201).json({uuid: uuid, token: token});
      });
    });
  });

  server.post('/devices/:uuid/tokens', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('generateAndStoreToken', req, fromDevice));

      var mergedParams = _.assign({}, req.params, req.body);
      generateAndStoreToken(fromDevice, mergedParams, function(error, result){
        if(error){
          meshbluEventEmitter.emit('generatetoken-error', {request: {uuid: req.params.uuid}, error: error.message, fromUuid: fromDevice.uuid});
          return errorResponse(error.message, res);
        }
        var uuid = req.params.uuid || fromDevice.uuid;

        meshbluEventEmitter.emit('generatetoken', {request: {uuid: req.params.uuid}, fromUuid: fromDevice.uuid});
        var tokenOptions = {uuid: uuid, token: result.token};
        if(mergedParams.tag){
          tokenOptions.tag = mergedParams.tag;
        }
        res.json(tokenOptions);
      });
    });
  });

  server.delete('/devices/:uuid/tokens/:token', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('revokeToken', req, fromDevice));

      revokeToken(fromDevice, req.params.uuid, req.params.token, function(error, result){
        if(error){
          meshbluEventEmitter.emit('revoketoken-error', {request: {uuid: req.params.uuid}, error: error.message, fromUuid: fromDevice.uuid});
          return errorResponse(error.message, res);
        }
        meshbluEventEmitter.emit('revoketoken', {request: {uuid: req.params.uuid}, fromUuid: fromDevice.uuid});
        res.sendStatus(204);
      });
    });
  });

  // curl -X POST -d "name=arduino&description=this+is+a+test" http://localhost:3000/devices
  server.post('/devices', function(req, res){
    skynet.sendActivity(getActivity('devices',req));
    req.merged_params.ipAddress = req.merged_params.ipAddress || getIP(req);

    register(req.merged_params, function(error, device){
      if(error){
        meshbluEventEmitter.emit('register-error', {request: req.merged_params, error: error.message});
        return res.status(500).json(error.message);
      }

      meshbluEventEmitter.emit('register', {request: req.merged_params});
      res.status(201).json(device);
    });
  });

  // curl -X POST -d "name=arduino&description=this+is+a+test" http://localhost:3000/devices/micro
  server.post('/devices/micro', function(req, res){
    skynet.sendActivity(getActivity('devices/micro',req));
    req.merged_params.ipAddress = req.merged_params.ipAddress || getIP(req);
    res.contentType = 'text';

    register(req.merged_params, function(error, device){
      if(error) {
        meshbluEventEmitter.emit('micro-error', {request: req.merged_params, error: error.message});
        return res.send(400, null);
      }

      meshbluEventEmitter.emit('micro', {request: req.merged_params});
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
      updateFromClient(fromDevice, _.defaults({uuid: req.params.uuid}, req.merged_params), function(result){
        var requestLog = {query: {uuid: req.params.uuid}, params: req.merged_params}
        if(result.error){
          meshbluEventEmitter.emit('update-error', {request: requestLog, fromUuid: fromDevice.uuid, error: result.error.message});
          return errorResponse(result.error, res);
        }

        meshbluEventEmitter.emit('update', {request: requestLog, fromUuid: fromDevice.uuid});
        res.json(result);
      });
    });
  });

  // curl -X DELETE -d "token=123" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
  server.delete('/devices/:uuid', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('unregister',req, fromDevice));
      unregister(fromDevice, req.params.uuid, req.merged_params.token, skynet.emitToClient, function(err, data){
        if(err){
          meshbluEventEmitter.emit('unregister-error', {request: {uuid: req.params.uuid}, fromUuid: fromDevice.uuid, error: err});
          return errorResponse(err, res);
        }

        meshbluEventEmitter.emit('unregister', {request: {uuid: req.params.uuid}, fromUuid: fromDevice.uuid});
        res.json(data);
      });
    });

  });

  // Returns all devices owned by authenticated user
  // curl -X GET http://localhost:3000/mydevices/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc?token=qirqglm6yb1vpldixflopnux4phtcsor
  server.get('/mydevices', function(req, res){
    var query = req.query || {};
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('mydevices',req, fromDevice));
      query.owner = fromDevice.uuid;
      getDevices(fromDevice, query, true, function(error, data){
        if(data.error){
          meshbluEventEmitter.emit('devices-error', {request: query, error: data.error.message, fromUuid: fromDevice.uuid});
          return errorResponse(data.error, res);
        }

        meshbluEventEmitter.emit('devices', {request: query, fromUuid: fromDevice.uuid});
        res.json(data);
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
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('subscribe',req, fromDevice));
      meshbluEventEmitter.emit('subscribe', {request: {uuid: req.params.uuid}, fromUuid: fromDevice.uuid});
      logEvent(204, {fromUuid: fromDevice.uuid, from: fromDevice});

      res.setHeader('Connection', 'keep-alive');
      var requestedSubscriptionTypes = req.merged_params.types || ['broadcast', 'received', 'sent'];
      subscribeAndForward(fromDevice, res, req.params.uuid, req.merged_params.token, requestedSubscriptionTypes, false, req.merged_params.topics);
    });
  });

  // curl -X GET http://localhost:3000/subscribe/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc/broadcast
  server.get('/subscribe/:uuid/broadcast', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('subscribe',req, fromDevice));
      meshbluEventEmitter.emit('subscribe', {request: {uuid: req.params.uuid, type: 'broadcast'}, fromUuid: fromDevice.uuid});
      logEvent(204, {fromUuid: fromDevice.uuid, from: fromDevice});

      res.setHeader('Connection', 'keep-alive');
      subscribeAndForward(fromDevice, res, req.params.uuid, req.merged_params.token, ['broadcast'], false, req.merged_params.topics);
    });
  });

  // curl -X GET http://localhost:3000/subscribe/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc/received
  server.get('/subscribe/:uuid/received', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('subscribe',req, fromDevice));
      meshbluEventEmitter.emit('subscribe', {request: {uuid: req.params.uuid, type: 'received'}, fromUuid: fromDevice.uuid});
      logEvent(204, {fromUuid: fromDevice.uuid, from: fromDevice});

      res.setHeader('Connection', 'keep-alive');
      subscribeAndForward(fromDevice, res, req.params.uuid, req.merged_params.token, ['received'], false, req.merged_params.topics);
    });
  });

  // curl -X GET http://localhost:3000/subscribe/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc/sent
  server.get('/subscribe/:uuid/sent', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('subscribe',req, fromDevice));
      meshbluEventEmitter.emit('subscribe', {request: {uuid: req.params.uuid, type: 'sent'}, fromUuid: fromDevice.uuid});
      logEvent(204, {fromUuid: fromDevice.uuid, from: fromDevice});

      res.setHeader('Connection', 'keep-alive');
      subscribeAndForward(fromDevice, res, req.params.uuid, req.merged_params.token, ['sent'], false, req.merged_params.topics);
    });
  });

  // curl -X GET http://localhost:3000/subscribe
  server.get('/subscribe', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('subscribe',req, fromDevice));
      meshbluEventEmitter.emit('subscribe', {request: {}, fromUuid: fromDevice.uuid});
      //var uuid = req.params.uuid;
      logEvent(204, {fromUuid: fromDevice.uuid, from: fromDevice});

      res.setHeader('Connection', 'keep-alive');
      subscribeAndForward(fromDevice, res);
    });
  });

  // curl -X GET http://localhost:3000/authenticate/81246e80-29fd-11e3-9468-e5f892df566b?token=5ypy4rurayktke29ypbi30kcw5ovfgvi
  server.get('/authenticate/:uuid', function(req, res){
    skynet.sendActivity(getActivity('authenticate',req));
    res.setHeader('Access-Control-Allow-Origin','*');
    authDevice(req.params.uuid, req.merged_params.token, function(error, device){
      if (!device) {
        var regdata = {
          "error": {
            "message": "Device not found or token not valid",
            "code": 404
          }
        };
        meshbluEventEmitter.emit('identity-error', {request: {uuid: req.params.uuid}, error: regdata.error.message});
        return res.status(regdata.error.code).send({uuid:req.params.uuid, authentication: false});
      }

      meshbluEventEmitter.emit('identity', {request: {uuid: req.params.uuid}});
      res.json({uuid:req.params.uuid, authentication: true});
    });
  });


  // curl -X POST -d '{"devices": "all", "payload": {"yellow":"off"}}' http://localhost:3000/messages
  // curl -X POST -d '{"devices": ["ad698900-2546-11e3-87fb-c560cb0ca47b","2f3113d0-2796-11e3-95ef-e3081976e170"], "payload": {"yellow":"off"}}' http://localhost:3000/messages
  // curl -X POST -d '{"devices": "ad698900-2546-11e3-87fb-c560cb0ca47b", "payload": {"yellow":"off"}}' http://localhost:3000/messages
  server.post('/messages', function(req, res, next){
    authorizeRequest(req, res, function(fromDevice){
      //skynet.sendActivity(getActivity('messages',req));
      var message = req.merged_params;

      if (_.isEmpty(message.devices)) {
        meshbluEventEmitter.emit('message-error', {request: message, error: 'Invalid Message Format', fromUuid: fromDevice.uuid});
        res.status(422).send({error: 'Invalid Message Format'});
        return;
      }

      res.json(message);

      meshbluEventEmitter.emit('message', {request: message, fromUuid: fromDevice.uuid});
      skynet.sendMessage(fromDevice, message);
      logEvent(300, message);
    });
  });

  // curl -X POST -d "token=123&temperature=78" http://localhost:3000/data/ad698900-2546-11e3-87fb-c560cb0ca47b
  server.post('/data/:uuid', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('data',req, fromDevice));
      saveDataIfAuthorized(skynet.sendMessage, fromDevice, req.params.uuid, req.merged_params, function(error, data){
        if(error){
          meshbluEventEmitter.emit('data-error', {request: req.merged_params, error: error.message, fromUuid: fromDevice.uuid});
          return res.status(422).end();
        }
        meshbluEventEmitter.emit('data', {request: req.merged_params, fromUuid: fromDevice.uuid});
        res.status(201).end();
      });
    });
  });

  // curl -X GET http://localhost:3000/data/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc?token=qirqglm6yb1vpldixflopnux4phtcsor
  server.get('/data/:uuid', function(req, res){
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity(getActivity('data',req, fromDevice));
      logEvent(701, {fromUuid: fromDevice.uuid, from: fromDevice});
      meshbluEventEmitter.emit('subscribe', {request: {uuid: req.params.uuid, type: 'data'}, fromUuid: fromDevice.uuid});

      if(req.query.stream){
        res.setHeader('Connection', 'keep-alive');
        subscribeAndForward(fromDevice, res, req.params.uuid, req.merged_params.token, ['broadcast'], true);
      }
      else{
        getData(req, function(data){
          if(data.error){
            errorResponse(data.error, res);
          } else {
            res.json(data);
          }
        });
      }
    });
  });

  server.get('/js/meshblu.js', function(req, res){
    res.redirect(301, 'https://cdn.octoblu.com/js/meshblu/latest/meshblu.bundle.js');
  });

  server.get('/jsconsole', function(req, res){
    res.redirect(301, 'https://developer.octoblu.com/jsconsole');
  });

  server.get('/', function(req, res){
    res.redirect(301, 'https://developer.octoblu.com');
  });

  return server;
}

module.exports = setupHttpRoutes;
