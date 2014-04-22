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

module.exports = function (app) {
  var config = require('../config').coap[app.env || 'development'];

  coapServer.on('request', coapRouter.process);

  coapServer.listen(config.port, config.host, function () {
    console.log('[coap] listening at http://' + config.host + ':' + config.port);
  });

  return coapServer;
};
