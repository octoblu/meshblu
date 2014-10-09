var getDevices = require('./getDevices');

var r192 = new RegExp(/^192\.168\./);
var r10 = new RegExp(/^10\./);

module.exports = function(fromDevice, unclaimedOnly, callback){
  if(!fromDevice || !fromDevice.ipAddress){
    callback({error: {
          message: "No ipAddress on device",
          code: 404
        }
    });
  }

  var ip = fromDevice.ipAddress;
  var query = {};

  if(r192.test(ip)){
    query.ipAddress = r192;
  }
  else if(r10.test(ip)){
    query.ipAddress = r10;
  }
  else{
    query.ipAddress = ip;
  }
  //TODO 20-bit block 172.16.0.0 - 172.31.255.255

  if(unclaimedOnly){
    query.owner = { $exists: false };
  }

  query.type = { $ne: 'user' };

  getDevices(fromDevice, query, false, callback);
};
