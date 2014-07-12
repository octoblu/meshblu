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
      console.log('\n from db', merr, mdata);
      callback(null, mdata);
    }
  });
}

function getDevice(uuid, callback){
  if(config.redis){
    redis.get('DEVICE_' + uuid, function(rerr, rdata){
      if(!rdata){
        dbGet(uuid, function(merr, mdata){
          if(!merr){
            //console.log('saving to redis',merr, mdata);
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
  console.log(uuid);

  try{
    getDevice(uuid, function(err, devicedata){
      if(err){
        callback(err);
      }else{

        if(!owner){
          delete devicedata.token;
        }

        //console.log('devicedata', devicedata, config);
        //devicedata._id.toString();
        delete devicedata._id;
        delete devicedata.timestamp;
        console.log('Device whoami: ' + JSON.stringify(devicedata));

        callback(devicedata);
      }
    });
  }catch(exp){
    console.log('error retrieving device info', exp);
    callback({error: exp});
  }


};
