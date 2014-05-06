var redis = require('./redis');
var config = require('../config');

var TIMEOUT = config.bindTimeout || 3600;

function connect(client, target, callback){
  redis.setex('SOCKET_BIND_' + client, TIMEOUT, target);
  redis.setex('SOCKET_BIND_' + target, TIMEOUT, client, callback);
}

function disconnect(client){
  getTarget(client, function(err, target){
    if(target){
      console.log('unbinding', client, target);
      redis.del('SOCKET_BIND_' + client);
      redis.del('SOCKET_BIND_' + target);
    }
  });
}



function getTarget(client, callback){
  redis.get('SOCKET_BIND_' + client, callback);
}

module.exports = {
  connect: connect,
  disconnect: disconnect,
  getTarget: getTarget
};
