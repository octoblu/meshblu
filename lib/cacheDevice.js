var config = require('./../config');
var redis = require('./redis');

var _ = require('lodash');

function cacheDevice(device){

  if(device){
    var cloned = _.clone(device);
    redis.set('DEVICE_' + device.uuid, JSON.stringify(cloned),function(){
      //console.log('cached', uuid);
    });
  }

}

function noop(){}

if(config.redis){
  module.exports = cacheDevice;
}
else{
  module.exports = noop;
}
