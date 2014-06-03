var redis = require('socket.io/node_modules/redis');
var RedisStore = require('socket.io/lib/stores/redis');
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

    // Setup RedisStore for socket.io scaling
    var pub, store, sub;

    pub = redis.createClient(config.redis.port, config.redis.host, options);
    sub = redis.createClient(config.redis.port, config.redis.host, options);
    store = redis.createClient(config.redis.port, config.redis.host, options);
    pub.auth(config.redis.password, function(err) {
      if (err) {
        throw err;
      }
    });
    sub.auth(config.redis.password, function(err) {
      if (err) {
        throw err;
      }
    });
    store.auth(config.redis.password, function(err) {
      if (err) {
        throw err;
      }
    });

    return new RedisStore({
      redisPub: pub,
      redisSub: sub,
      redisClient: store
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
};
