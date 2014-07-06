var config = require('./../config');

var devices = require('./database').devices;
module.exports = function(uuid, owner, callback) {
  console.log(uuid);
  devices.findOne({
    uuid: uuid
  }, function(err, devicedata) {

    if(err || devicedata == undefined || devicedata == null || devicedata.length < 1) {

      var regdata = {
        error: {
          uuid: uuid,
          message: 'Device not found',
          code: 404
        }
      };
      callback(regdata);

    } else {

      if(!owner){
        if (devicedata.type == 'gateway' && devicedata.owner == undefined ){

        } else {
          // remove token from results object
          delete devicedata.token;
        }
      }

      devicedata._id.toString();
      delete devicedata._id;
      delete devicedata.timestamp;
      console.log('Device whoami: ' + JSON.stringify(devicedata));

      callback(devicedata);
    }
  });
};
