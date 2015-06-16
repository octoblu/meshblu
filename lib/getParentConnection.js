'use strict';

var config = require('../config');
var skynetClient = require('meshblu');

var parentConnection =  null;

if(config.parentConnection && config.parentConnection.uuid){

  parentConnection = skynetClient.createConnection(config.parentConnection);
  parentConnection.on('notReady', function(data){
    console.log('Failed authenitication to parent cloud', data);
  });

  parentConnection.on('ready', function(data){
    console.log('UUID authenticated for parent cloud connection.', data);
  });

}

module.exports = parentConnection;
