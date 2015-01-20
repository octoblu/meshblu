var config = require('./../config');
var devices = require('./database').devices;
var redis = require('./redis');
var cacheDevice = require('./cacheDevice');


function genError(uuid){
  return {
    error: {
      uuid: uuid,
      message: 'Device not found',
      code: 404
    }
  };
}


function dbGet(uuid, callback){
  devices.findOne({
    uuid: uuid
  }, function(merr, mdata) {
    if(merr || !mdata) {
      callback(genError(uuid));
    }else{
      delete mdata.token;
      callback(null, mdata);
    }
  });
}

function getDevice(uuid, callback){
  if(config.redis && config.redis.host){
    redis.get('DEVICE_' + uuid, function(rerr, rdata){
      if(!rdata){
        dbGet(uuid, function(merr, mdata){
          if(!merr){
            cacheDevice(mdata);
          }
          callback(merr, mdata);
          //store to redis in background

        });
      }else{
        callback(null, JSON.parse(rdata));
      }
    });
  }else{
    dbGet(uuid, callback);
  }
}

module.exports = function(uuid, owner, callback) {
  try{
    getDevice(uuid, function(err, devicedata){
      if(err){
        callback(err);
      }else{
        delete devicedata._id;
        delete devicedata.timestamp;
        callback(devicedata);
      }
    });
  }catch(exp){
    console.error(exp);
    callback({error: exp});
  }
};
