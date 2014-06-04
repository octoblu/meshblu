'use strict';
var mosca = require('mosca');
var config = require('./config');
var updateSocketId = require('./lib/updateSocketId');

var server;

config.mqtt = config.mqtt || {};

var dataStore = {
  type: 'mongo',
  url: config.mqtt.databaseUrl,
  pubsubCollection: 'mqtt',
  mongo: {}
};

var dataLogger = {
    level: 'debug'
};

var settings = {
  port: config.mqtt.port || 1883,
  backend: dataStore,
  logger: dataLogger
};

function endsWith(str, suffix) {
  return str.indexOf(suffix, str.length - suffix.length) !== -1;
}

process.on("uncaughtException", function(error) {
  return console.log(error.stack);
});

// Accepts the connection if the username and password are valid
function authenticate(client, username, password, callback) {
  console.log('authenticate username:', username.toString(),'password', password.toString(),'client.id:', client.id, client.clientId, client.client_id);

  if(username && username.toString() === 'skynet'){
    if(password && password.toString() === config.mqtt.skynetPass){
      client.skynetDevice = {
        uuid: 'skynet',
      };
      callback(null, true);
    }else{
      callback('unauthorized');
    }
  }else{
    var data = {
      uuid: username.toString(),
      token: password.toString(),
      socketid: username.toString(),
      protocol: 'mqtt',
      online: 'true'
    };

    console.log('attempting authenticate', data);


    updateSocketId(data, function(auth){
      if (auth.status == 201){
          client.skynetDevice = auth.device;
          console.log('authenticated: ' + auth.device.uuid);
          callback(null, true);

      } else {
        callback('unauthorized');
      }

    });
  }


}

// In this case the client authorized as alice can publish to /users/alice taking
// the username from the topic and verifing it is the same of the authorized user
function authorizePublish(client, topic, payload, callback) {

  function reject(){
    callback('unauthorized');
    console.log('\nunauthorized Publish', topic, client.id);
  }

  //TODO refactor this mess
  if(client.skynetDevice){
    if(client.skynetDevice.uuid === 'skynet'){
      callback(null, true);
    }else if(topic === 'skynet'){
      try{
        var payloadObj = JSON.parse(payload.toString());
        if(payloadObj.fromUuid === client.skynetDevice.uuid){
          callback(null, true);
          console.log('\nauthorized Publish', topic, client.id);
        }else{
          reject();
        }
      }catch(err){
        reject();
      }
    }else{
      reject();
    }
  }else{
    reject();
  }

}

// In this case the client authorized as alice can subscribe to /users/alice taking
// the username from the topic and verifing it is the same of the authorized user
function authorizeSubscribe(client, topic, callback) {

  if(endsWith(topic, '_bc') ||
    (client.skynetDevice &&
      ((client.skynetDevice.uuid === 'skynet') || (client.skynetDevice.uuid === topic)))){
    callback(null, true);
    console.log('authorized subscribe', topic, client.skynetDevice);
  }else{
    callback('unauthorized');
  }

}

// fired when the mqtt server is ready
function setup() {
  console.log('Skynet MQTT server started on port', config.port);
  server.authenticate = authenticate;
  server.authorizePublish = authorizePublish;
  server.authorizeSubscribe = authorizeSubscribe;
}

// // fired when a message is published

server = new mosca.Server(settings);
server.on('ready', setup);

server.on('published', function(packet, client) {
   //console.log('Published', packet, client);
});

// fired when a client connects or disconnects
server.on('clientConnected', function(client) {
  console.log('Client Connected:', client.id);
});

server.on('clientDisconnected', function(client) {
  console.log('Client Disconnected:', client.id);
});
