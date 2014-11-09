var redis = require('redis');
var redisStore = require('socket.io-redis');
var subEvents = require('./subEvents');
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

    //additional message handler for non-socket.io clients
    subClient.on('pmessage', function(pattern, channel, msg){
      try{
        msg = msgpack.decode(msg);
        _.forEach(msg[1].rooms, function(room){
          subEvents.emit(room, msg[0].data[0],  msg[0].data[1]);
        });
      }catch(exp){
        console.error('unable to handle pmessage', exp);
      }

    });

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
    createIoStore:  createIoStore,
    get: client.get.bind(client),
    set: client.set.bind(client),
    del: client.del.bind(client),
    setex: client.setex.bind(client),
    client: client
  };
}
