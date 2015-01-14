var mdnsServer = function(config, options){
  options = options || {};
  var mdns = options.mdns || require('mdns');

  return mdns.createAdvertisement(mdns.tcp('meshblu'), parseInt(config.port, 10));
};

module.exports = mdnsServer;
