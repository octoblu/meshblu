var messageIOEmitter = require('./createMessageIOEmitter')();
var whoAmI = require('./whoAmI');

function sendConfigActivity(uuid, emitter){
  whoAmI(uuid, true, function(device) {
    if (emitter){
      emitter('config', device, device);
    } else {
      messageIOEmitter(uuid, 'config', device);
    }
  });
}

module.exports = sendConfigActivity;
