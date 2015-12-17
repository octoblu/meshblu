var redis = require('redis');
var redisStore = require('socket.io-redis');
var msgpack = require('msgpack-js');
var config = require('../config');
var _ = require('lodash');

function createClient(options){

  var client = redis.createClient(config.redis.port, config.redis.host, options);

  client.auth(config.redis.password, function(err){
    if(err){
      throw err;
    }
  });

  return client;
}

function createIoStore(){

  if(config.redis && config.redis.host){
    var pubClient = createClient({ detect_buffers:true });
    var subClient = createClient({ detect_buffers:true });

    var store = redisStore({
      host: config.redis.host,
      port: config.redis.port,
      pubClient: pubClient,
      subClient: subClient
    });

    store.pubClient = pubClient;
    store.subClient = subClient;

    return store;
  }
}

var client;

if(config.redis && config.redis.host){
  client = createClient();
} else {
  var fakeredis = require('fakeredis');
  client = fakeredis.createClient();
  createClient = fakeredis.createClient;
}

client = _.bindAll(client);

module.exports = {
  CACHE_KEY: 'cache:device:',
  CACHE_TIMEOUT: 300, // in seconds
  createIoStore:  createIoStore,
  get: client.get,
  set: client.set,
  exists: client.exists,
  del: client.del,
  sadd: client.sadd,
  srem: client.srem,
  setex: client.setex,
  sismember: client.sismember,
  client: client,
  createClient: createClient
};
