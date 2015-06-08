var config = require('../config');
var messageIOEmitter = require('./createMessageIOEmitter')();

function sendActivity(data){
  //TODO throttle
  if(config.broadcastActivity && data && data.ipAddress){
    messageIOEmitter(config.uuid + '_bc', 'message', data);
  }
}

module.exports = sendActivity;
