var redis = require('redis');
var redisStore = require('socket.io-redis');

var config = require('../config');



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

  if(config.redis){
    var pubClient = createClient({ detect_buffers:true });
    var subClient = createClient({ detect_buffers:true });

    return redisStore({
      host: config.redis.host,
      port: config.redis.port,
      pubClient: pubClient,
      subClient: subClient
    });

  }
}

if(config.redis){
  var client = createClient({parser: "javascript"});
  module.exports = {
    createIoStore:  createIoStore,
    get: client.get.bind(client),
    set: client.set.bind(client),
    del: client.del.bind(client),
    setex: client.setex.bind(client),
    client: client
  };
}
