var socketEmitter = require('./createSocketEmitter')();
var whoAmI = require('./whoAmI');

function sendConfigActivity(uuid, emitter){
  whoAmI(uuid, true, function(device) {
    if (emitter){
      emitter('config', device, device);
    } else {
      socketEmitter(uuid, 'config', device);
    }
  });
}

module.exports = sendConfigActivity;
