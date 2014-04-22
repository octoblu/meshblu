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
    console.log(data);
    if(data.error){
      res.json(data.error.code, data);
    } else {
      res.json(data);
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
