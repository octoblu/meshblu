'use strict';

var skynetClient = require('skynet'); //skynet npm client

var parentConnection = function(config){
  if(!config.parentConnection.uuid){
    return;
  }

  var conn = skynetClient.createConnection(config.parentConnection);
  conn.on('notReady', function(data){
    console.log('Failed authenitication to parent cloud', data);
  });

  conn.on('ready', function(data){
    console.log('UUID authenticated for parent cloud connection.', data);
  });

  return conn;
};

module.exports = parentConnection;
