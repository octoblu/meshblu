var config = require('../config');
var redis = require('./redis');
var subEvents = require('./subEvents');

var redisIoEmitter;

if(config.redis && config.redis.host){
  redisIoEmitter = require('socket.io-emitter')(redis.client);
}

module.exports = function(io, ios){
  if(redisIoEmitter){
    return function(channel, topic, data){
      redisIoEmitter.in(channel).emit(topic, data);
    };
  }else if(io){
    return function(channel, topic, data){
      io.sockets.in(channel).emit(topic, data);
      if(ios){
        ios.sockets.in(channel).emit(topic, data);
      }
      //for local http streaming:
      subEvents.emit(channel, topic, data);
    };
  }else{
    return function(){};
  }
};
