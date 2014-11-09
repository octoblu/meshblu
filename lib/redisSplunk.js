var redis  = require('redis');
var config = require('./../config');

var redisSplunk;

var RedisSplunk = function(options){
  var self, client;

  self   = this;
  client = redis.createClient(options.port, options.host);
  client.auth(options.password, console.error);

  self.log = function(data, callback){
    client.rpush('splunk', JSON.stringify(data), callback);
  };
};

RedisSplunk.log = function(data, callback){
  if(!config.redis) {
    return callback();
  }

  if(!redisSplunk) {
    redisSplunk = new RedisSplunk(config.redis);
  }

  redisSplunk.log(data, callback);
};

module.exports = RedisSplunk;
