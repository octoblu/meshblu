var config = require('./../config');
var redis = require('./redis');


function clearCache(name){

  if(name && config.redis && config.redis.host){
    redis.del(name, function(){
    });
  }

}

function noop(){}

if(config.redis && config.redis.host){
  module.exports = clearCache;
}
else{
  module.exports = noop;
}
