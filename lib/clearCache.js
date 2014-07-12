var config = require('./../config');
var redis = require('./redis');


function clearCache(name){

  if(name){
    redis.del(name, function(){
      //console.log('cached', uuid);
    });
  }

}

function noop(){}

if(config.redis){
  module.exports = clearCache;
}
else{
  module.exports = noop;
}
