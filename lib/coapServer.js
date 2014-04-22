var coap       = require('coap'),
    coapRouter = require('./coapRouter'),
    coapServer = coap.createServer();

coapRouter.get('/status', function (req, res) {
  require('./getSystemStatus')(function (data) {
    if(data.error) {
      console.log(data.error.code, data);
      res.json(data.error.code, data);
    } else {
      console.log(data);
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
