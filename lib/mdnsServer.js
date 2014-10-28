var mdns = require('mdns');

var mdnsServer = function(config) {
  return mdns.createAdvertisement(
    mdns.tcp('meshblu'), 
    parseInt(config.port, 10)
  );
}

module.exports = mdnsServer;
