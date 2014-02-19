var devices = require('./database').collection('devices');

module.exports = function(uuid, owner, callback) {
  console.log(uuid);
  devices.findOne({
    uuid: {"$regex":uuid,"$options":"i"}
  }, function(err, devicedata) {

    if(err || devicedata == undefined || devicedata == null || devicedata.length < 1) {

      var regdata = {
        "error": {
          "uuid": uuid,
          "message": "Device not found",
          "code": 404
        }
      };
      require('./logEvent')(500, regdata);
      callback(regdata);


    } else {

      if(!owner){
        if (devicedata.type == 'gateway' && devicedata.owner == undefined ){
          
        } else {  
          // remove token from results object
          delete devicedata.token;
        }
      }
      console.log('Device whoami: ' + JSON.stringify(devicedata));

      require('./logEvent')(500, devicedata);
      callback(devicedata);
    }
  });
};