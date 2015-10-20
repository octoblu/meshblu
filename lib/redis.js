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

if(config.redis && config.redis.host){
  var client = createClient({parser: "javascript"});
  module.exports = {
    CACHE_KEY: 'cache:DEVICE_',
    CACHE_TIMEOUT: 300, // in seconds
    createIoStore:  createIoStore,
    get: client.get.bind(client),
    set: client.set.bind(client),
    del: client.del.bind(client),
    sadd: client.sadd.bind(client),
    setex: client.setex.bind(client),
    sismember: client.sismember.bind(client),
    client: client,
    createClient: createClient
  };
}
