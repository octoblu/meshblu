var redis = require('redis');
var redisStore = require('socket.io-redis');

var config = require('../config');

var options = {
  parser: "javascript"
};

if(config.redis){
  var client = redis.createClient(config.redis.port, config.redis.host, options);

  client.auth(config.redis.password, function(err){
    if(err){
      throw err;
    }
  });
}


function createIoStore(){

  if(config.redis){

    return redisStore({
      host: config.redis.host,
      port: config.redis.port,
      pubClient: client,
      subClient: client
    });

  }
}

if(config.redis){
  module.exports = {
    createIoStore:  createIoStore,
    get: client.get.bind(client),
    set: client.set.bind(client),
    del: client.del.bind(client),
    setex: client.setex.bind(client)
  };
}
