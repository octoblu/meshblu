var redis = require('socket.io/node_modules/redis');
var RedisStore = require('socket.io/lib/stores/redis');
var config = require('../config');

var options = {
  parser: "javascript"
};

var client = redis.createClient(config.redisPort, config.redisHost, options);

client.auth(config.redisPassword, function(err){
  if(err){
    throw err;
  }
});


function createIoStore(){
  // Setup RedisStore for socket.io scaling
  var pub, store, sub;

  pub = redis.createClient(config.redisPort, config.redisHost, options);
  sub = redis.createClient(config.redisPort, config.redisHost, options);
  store = redis.createClient(config.redisPort, config.redisHost, options);
  pub.auth(config.redisPassword, function(err) {
    if (err) {
      throw err;
    }
  });
  sub.auth(config.redisPassword, function(err) {
    if (err) {
      throw err;
    }
  });
  store.auth(config.redisPassword, function(err) {
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

module.exports = {
  createIoStore:  createIoStore,
  get: client.get.bind(client),
  set: client.set.bind(client),
  del: client.del.bind(client),
  setex: client.setex.bind(client)
};
