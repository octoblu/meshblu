var socketEmitter = require('./createSocketEmitter')();
var whoAmI = require('./whoAmI');

function sendConfigActivity(uuid){
  whoAmI(uuid, true, function(data) {
    socketEmitter(uuid, 'config', data);
  });
}

module.exports = sendConfigActivity;
