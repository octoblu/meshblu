var JSONStream = require('JSONStream');

var whoAmI = require('./whoAmI');
var config = require('../config');
var getData = require('./getData');
var logData = require('./logData');
var logEvent = require('./logEvent');
var register = require('./register');
var subscribe = require('./subscribe');
var getDevices = require('./getDevices');
var authDevice = require('./authDevice');
var unregister = require('./unregister');
var getSystemStatus = require('./getSystemStatus');
var updateFromClient = require('./updateFromClient');
var _ = require('lodash');

//psuedo middleware
function authorizeRequest(req, res, callback){
  var uuid = _.find(req.options, {name:'98'});
  var token = _.find(req.options, {name:'99'});
  if (uuid && uuid.value) {
    uuid = uuid.value.toString();
  }
  if (token && token.value) {
    token = token.value.toString();
  }
  authDevice(uuid, token, function (auth) {
    if (auth.authenticate) {
      callback(auth.device);
    }else{
      res.statusCode = 401;
      res.json({error: 'unauthorized'});
    }
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

function setupCoapRoutes(coapRouter, skynet){

  // coap get coap://localhost/status
  coapRouter.get('/status', function (req, res) {
    skynet.sendActivity({ipAddress: req.rsinfo.address});

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
    skynet.sendActivity({ipAddress: req.rsinfo.address});

    res.json({ipAddress: req.rsinfo.address});
  });

  coapRouter.get('/devices', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity({ipAddress: req.rsinfo.address});

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
    skynet.sendActivity({ipAddress: req.rsinfo.address});

    req.params.ipAddress = req.rsinfo.address
    register(req.params, function (data) {
      if(data.error) {
        res.statusCode = data.error.code;
        res.json(data.error);
      } else {
        res.json(data);
      }

    });
  });

  // coap get coap://localhost/devices/a1634681-cb10-11e3-8fa5-2726ddcf5e29
  coapRouter.get('/devices/:uuid', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity({ipAddress: req.rsinfo.address});
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
      skynet.sendActivity({ipAddress: req.rsinfo.address});
      updateFromClient(fromDevice, req.params, function(result){
        if(result.error){
          errorResponse(result.error, res);
        }else{
          res.json(result);
        }
      });
    });
  });

  coapRouter.delete('/devices/:uuid', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity({ipAddress: req.rsinfo.address});
      unregister(fromDevice, req.params.uuid, function(err, data){
        if(err){
          errorResponse(err, res);
        } else {
          res.json(data);
        }
      });
    });

  });


  coapRouter.get('/mydevices', function (req, res) {
     authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity({ipAddress: req.rsinfo.address});
      getDevices(fromDevice, {owner: fromDevice.uuid}, true, function(data){
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
      skynet.sendActivity({ipAddress: req.rsinfo.address});
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

  // coap get coap://localhost/events/196798f1-b5d8-11e3-8c93-45a0c0308eaa -p "token=00cpk8akrmz8semisbebhe0358livn29"
  coapRouter.get('/events/:uuid', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity({ipAddress: req.rsinfo.address});
      logEvent(201, {fromUuid: fromDevice, uuid: req.params.uuid});
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
      skynet.sendActivity({ipAddress: req.rsinfo.address});
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
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity({ipAddress: req.rsinfo.address});
      if(req.query.stream){

        var foo = JSONStream.stringify(open='\n', sep=',\n', close='\n\n');
        foo.on("data", function(data){
          return data;
        });
        getData(req)
          .pipe(foo)
          .pipe(res);

      } else {
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

  // coap post coap://localhost/messages -p "devices=a1634681-cb10-11e3-8fa5-2726ddcf5e29&payload=test"
  coapRouter.post('/messages', function (req, res, next) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity({ipAddress: req.rsinfo.address});
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

  coapRouter.get('/subscribe/:uuid', function (req, res) {
    authorizeRequest(req, res, function(fromDevice){
      skynet.sendActivity({ipAddress: req.rsinfo.address});
        logEvent(204, {fromUuid: fromDevice, uuid: req.params.uuid});
        var foo = JSONStream.stringify(open='\n', sep=',\n', close='\n\n');
        foo.on("data", function(data){
          data = data + '\r\n';
        });
        subscribe(req.params.uuid)
          .pipe(foo)
          .pipe(res);
    });
  });
}

module.exports = setupCoapRoutes;
