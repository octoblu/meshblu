var config = require('../config');
var socketEmitter = require('./createSocketEmitter')();


function sendActivity(data){
  //TODO throttle
  if(config.broadcastActivity && data && data.ipAddress){
    socketEmitter(config.uuid + '_bc', 'message', data);
  }
}

module.exports = sendActivity;
