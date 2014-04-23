var coap       = require('coap'),
    coapRouter = require('./coapRouter'),
    coapServer = coap.createServer();


coapRouter.get('/status', function (req, res) {
  require('./getSystemStatus')(function (data) {
    console.log(data);
    if(data.error) {
      res.json(data.error.code, data);
    } else {
      res.json(data);
    }
  });
});


// A simple echo to test with
// TODO: remove after completion
['get', 'post', 'put', 'delete'].forEach(function (method) {
  coapRouter[method]('/echo', function (req, res) {
    res.json({method: method, url: req.url, options: req.options, payload: req.payload, query: req.query, params: req.params});
  });
});


coapRouter.get('/ipaddress', function (req, res) {
  res.json({ipAddress: req.rsinfo.address});
});


coapRouter.get('/devices', function(req, res){
  require('./getDevices')(req.query, false, function(data){
    if(data.error){
      res.statusCode = 404;
      res.json(data.error);
    } else {
      res.json(data);
    }
  });
});


coapRouter.post('/devices', function(req, res){
  req.params['ipAddress'] = req.rsinfo.address
  require('./register')(req.params, function(data){
    console.log(data);
    if(data.error){
      res.statusCode = 404;
      res.json(data.error);
    } else {
      res.json(data);
    }

  });
});


coapRouter.get('/devices/:uuid', function(req, res){
  require('./whoAmI')(req.params.uuid, false, function(data){
    console.log(data);
    if(data.error){
      res.statusCode = 404;
      res.json(data.error);
    } else {
      res.json(data);
    }

  });
});


coapRouter.put('/devices/:uuid', function(req, res){
  require('./updateDevice')(req.params.uuid, req.params, function(data){
    console.log(data);
    if(data.error){
      res.statusCode = 404;
      res.json(data.error);
    } else {
      res.json(data);
    }

  });
});


coapRouter.delete('/devices/:uuid', function(req, res){
  require('./unregister')(req.params.uuid, req.params, function(data){
    console.log(data);
    if(data.error){
      res.statusCode = 404;
      res.json(data.error);
    } else {
      res.json(data);
    }
  });
});


coapRouter.get('/mydevices/:uuid', function(req, res){
  require('./authDevice')(req.params.uuid, req.query.token, function(auth){
    if (auth.authenticate == true){
      req.query.owner = req.params.uuid;
      delete req.query.token;
      require('./getDevices')(req.query, true, function(data){
        console.log(data);
        if(data.error){
          res.statusCode = 404;
          res.json(data.error);
        } else {
          res.json(data);
        }
      });
    } else {
      console.log("Device not found or token not valid");
      regdata = {
        "error": {
          "message": "Device not found or token not valid",
          "code": 404
        }
      };
      if(regdata.error){
        res.statusCode = 404;
        res.json(regdata.error);
      } else {
        res.json(regdata);
      }

    }
  });
});


coapRouter.get('/gateway/:uuid', function(req, res){
  require('./whoAmI')(req.params.uuid, false, function(data){
    console.log(data);
    res.statusCode = 302;
    if(data.error){
      res.json({
        'location': 'http://skynet.im'
      });
    } else {
      res.json({
        'location': 'http://' + data.localhost + ":" + data.port
      });
    }
  });
});


module.exports = {
  setup : function (app) {
    coapServer.on('request', coapRouter.process);
    return coapServer;
  },
  listen : function (port, host, callback) {
    port = port || 5683;
    host = host || 'localhost';
    if(!callback) {
      callback = function () {
        console.log('[coap] listening at coap://' + host + ':' + port);
      };
    }

    coapServer.listen(port, host, callback);
    return coapServer;
  }
};
