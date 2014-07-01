/* Setup command line parsing and options
 * See: https://github.com/visionmedia/commander.js
 */
var _ = require('lodash');
var app = require('commander');
var tokenthrottle = require("tokenthrottle");
var restify = require('restify');
var socketio = require('socket.io');
var mqtt = require('mqtt');
var skynetClient = require('skynet'); //skynet npm client

var config = require(process.env.SKYNET_CONFIG || './config');
var securityImpl = require('./lib/getSecurityImpl');


var redis = require('./lib/redis');
var whoAmI = require('./lib/whoAmI');
var logEvent = require('./lib/logEvent');
var updateDevice = require('./lib/updateDevice');
var setupRestfulRoutes = require('./lib/setupHttpRoutes');
var setupCoapRoutes = require('./lib/setupCoapRoutes');
var setupMqttClient = require('./lib/setupMqttClient');
var socketLogic = require('./lib/socketLogic');

var fs = require('fs');
var setupGatewayConfig = require('./lib/setupGatewayConfig');

var parentConnection;

if(config.parentConnection){
  //console.log('logging into parent cloud', config.parentConnection, skynetClient);
  parentConnection = skynetClient.createConnection(config.parentConnection);
  parentConnection.on('notReady', function(data){
    console.log('Failed authenitication to parent cloud', data);
  });

  parentConnection.on('ready', function(data){
    console.log('UUID authenticated for parent cloud connection.', data);
  });

  parentConnection.on('message', function(data, fn){
    if(data){
      console.log('on message', data);
      if(!Array.isArray(data.devices) && data.devices != config.parentConnection.uuid){
        sendMessage({uuid: data.fromUuid}, data, fn);
      }
    }
  });
}

// sudo NODE_ENV=production forever start server.js --environment production
app
  .option('-e, --environment', 'Set the environment (defaults to development)')
  .parse(process.argv);

// console.log(app.environment || "running in development mode");
// if(!app.environment) app.environment = 'development';
if(app.args[0]){
  app.environment = app.args[0];
} else {
  app.environment = 'development';
}


// Create a throttle with 10 access limit per second.
// https://github.com/brycebaril/node-tokenthrottle
// var throttle = require("tokenthrottle")({
//   rate: 10,       // replenish actions at 10 per second
//   burst: 20,      // allow a maximum burst of 20 actions per second
//   window: 60000,   // set the throttle window to a minute
//   overrides: {
//     "127.0.0.1": {rate: 0}, // No limit for localhost
//     "Joe Smith": {rate: 10}, // token "Joe Smith" gets 10 actions per second (Note defaults apply here, does not inherit)
//     "2da0f39": {rate: 1000, burst: 2000, window: 1000}, // Allow a lot more actions to this token.
//   }
// });

config.rateLimits = config.rateLimits || {};
// rate per second
var throttles = {
  connection : tokenthrottle({rate: config.rateLimits.connection || 3}),
  message : tokenthrottle({rate: config.rateLimits.message || 10}),
  data : tokenthrottle({rate: config.rateLimits.data || 10}),
  query : tokenthrottle({rate: config.rateLimits.query || 2}),
  whoami : tokenthrottle({rate: config.rateLimits.whoami || 10}),
  unthrottledIps : config.rateLimits.unthrottledIps || []
};


// Instantiate our two servers (http & https)
var server = restify.createServer();
server.pre(restify.pre.sanitizePath());

if(config.tls){

  // Setup some https server options
  if(app.environment == 'development'){
    var https_options = {
      certificate: fs.readFileSync("../skynet_certs/server.crt"),
      key: fs.readFileSync("../skynet_certs/server.key")
    };
  } else {
    var https_options = {
      certificate: fs.readFileSync(config.tls.cert),
      key: fs.readFileSync(config.tls.key),
    };
  }

  var https_server = restify.createServer(https_options);
  https_server.pre(restify.pre.sanitizePath());
}

// Setup websockets
var io, ios;
io = socketio(server);
var redisStore;
if(config.redis){
  redisStore = redis.createIoStore();
  io.adapter(redisStore);
}

if(config.tls){
  ios = socketio(https_server);
  if(config.redis){
    io.adapter(redisStore);
  }
}

restify.CORS.ALLOW_HEADERS.push('skynet_auth_uuid');
restify.CORS.ALLOW_HEADERS.push('skynet_auth_token');
restify.CORS.ALLOW_HEADERS.push('accept');
restify.CORS.ALLOW_HEADERS.push('sid');
restify.CORS.ALLOW_HEADERS.push('lang');
restify.CORS.ALLOW_HEADERS.push('origin');
restify.CORS.ALLOW_HEADERS.push('withcredentials');
restify.CORS.ALLOW_HEADERS.push('x-requested-with');

// server.use(restify.acceptParser(server.acceptable));
server.use(restify.queryParser());
server.use(restify.bodyParser());
server.use(restify.CORS({ headers: [ 'skynet_auth_uuid', 'skynet_auth_token' ], origins: ['*'] }));
server.use(restify.fullResponse());

// Add throttling to HTTP API requests
// server.use(restify.throttle({
//   burst: 100,
//   rate: 50,
//   ip: true, // throttle based on source ip address
//   overrides: {
//     '127.0.0.1': {
//       rate: 0, // unlimited
//       burst: 0
//     }
//   }

process.on("uncaughtException", function(error) {
  return console.log(error.stack);
});


function cloneMessage(msg, device, fromUuid){
  var clonedMsg = _.clone(msg);
  clonedMsg.devices = device; //strip other devices from message
  delete clonedMsg.protocol;
  delete clonedMsg.api;
  clonedMsg.fromUuid = msg.fromUuid; // add from device object to message for logging
  return clonedMsg;
}

function sendToSocket(device, msg, callback){
  var socketServer = device.secure ? ios : io;

  if(socketServer){
    if(callback){
      //TODO acks should be done on clients - this doesnt work in cluster
      socketServer.sockets.connected[device.socketid].emit('message', msg, function(results){
        console.log('results', results);
        try{
          callback(results);
        } catch (e){
          console.log(e);
        }
      });
    }else{
      socketServer.sockets.in(device.uuid).emit('message', msg);
    }
  }
}



function handleUpdate(fromDevice, data, fn){

  whoAmI(data.uuid, false, function(check){

    if(check.error){
      return fn(check);
    }

    if(securityImpl.canUpdate(fromDevice, check)){
      updateDevice(data.uuid, data, function(results){
        console.log('update results', results);
        results.fromUuid = fromDevice;
        logEvent(401, results);

        try{
          fn(results);
        } catch (e){
          console.log(e);
        }

      });
    }else{
      fn({error: {message: 'unauthorized', code: 401} });
    }
  });

}

function wrapMqttMessage(topic, data){
  return JSON.stringify({topic: topic, data: data});
}

function forwardMessage(message, fn){
  if(parentConnection){
    try{
      parentConnection.message(message, fn);
    }catch(ex){
      console.log('error forwarding message', ex);
    }
  }
}

function sendMessage(fromDevice, data, fn){
  var fromUuid;
  if(fromDevice){
    fromUuid = fromDevice.uuid;
  }

  console.log("sendMessage() from", fromUuid, data);

  if(fromUuid){
    data.fromUuid = fromUuid;
  }

  if(data.token){
    //never forward token to another client
    delete data.token;
  }


    console.log('devices: ' + data.devices);
    console.log('message: ' + JSON.stringify(data));
    //console.log('protocol: ' + data.protocol); <- dont think this makes sense

    var devices = data.devices;

    if(devices == "all" || devices == "*"){

      if(fromUuid){
        io.sockets.in(fromUuid + '_bc').emit('message', data);
        if(config.tls){
          ios.sockets.in(fromUuid + '_bc').emit('message', data);
        }
        mqttclient.publish(fromUuid + '_bc', wrapMqttMessage('message', data), {qos:qos});
      }

      logEvent(300, data);

    } else {

      if(devices){

        if( typeof devices === 'string' ) {
          devices = [ devices ];
        }

        devices.forEach( function(device) {
          var toDeviceProp = device;
          if (device.length > 35){

            var deviceArray = device.split('/');
            if(deviceArray.length > 1){
              device = deviceArray.shift();
              toDeviceProp = deviceArray.join('/');
            }

            //check devices are valid
            whoAmI(device, false, function(check){
              var clonedMsg = cloneMessage(data, toDeviceProp, fromUuid);
              console.log('device check:', check);
              if(!check.error){
                if(securityImpl.canSend(fromDevice, check)){

                  // //to phone, but not from same phone
                  // if(check.phoneNumber && (clonedMsg.fromPhone !== check.phoneNumber)){
                  if(check.phoneNumber && check.type == "outboundSMS"){
                    // SMS handler
                    console.log("Sending SMS to", check.phoneNumber);
                    require('./lib/sendSms')(device, JSON.stringify(clonedMsg.payload), function(sms){
                      console.log('Sent SMS!', device, check.phoneNumber);
                    });
                  }

                  if(check.protocol === "mqtt"){
                    // MQTT handler
                    console.log('sending mqtt', device);
                    mqttclient.publish(device, JSON.stringify(clonedMsg), {qos:qos});
                  }
                  else{
                    // Websocket handler
                    if(fn && devices.length === 1 ){
                      console.log('sending with callback to: ', device);
                      sendToSocket(check, clonedMsg, fn);
                    }else{
                      sendToSocket(check, clonedMsg, null);
                    }
                  }

                  if(check.type == 'octobluMobile'){
                    // Push notification handler
                    console.log("Sending Push Notification to", check.uuid);
                    require('./lib/sendPushNotification')(check, JSON.stringify(clonedMsg.payload), function(push){
                      console.log('Sent Push Notification!', device);
                    });
                  }


                }else{
                  clonedMsg.UNAUTHORIZED=true; //for logging
                  console.log('unauthorized send attempt from', fromUuid, 'to', device);
                }

              }else{
                clonedMsg.INVALID_DEVICE=true; //for logging
                console.log('send attempt on invalid device from', fromUuid, 'to', device);
                //forward the message upward the tree
                forwardMessage(cloneMessage, fn);
              }

              var logMsg = _.clone(clonedMsg);
              logMsg.toUuid = check; // add to device object to message for logging
              logEvent(300, logMsg);

            });

          }

        });

      }

    }

}

var skynet = {
  handleUpdate: handleUpdate,
  sendMessage: sendMessage,
  gatewayConfig : setupGatewayConfig(io, ios),
  throttles: throttles,
  io: io,
  ios: ios
};

function checkConnection(socket, secure){
  //console.log(socket);
  // var ip = socket.handshake.address.address;
  var ip = socket.handshake.address;
  // var ip = socket.request.connection.remoteAddress
  // console.log(ip);

  if(_.contains(throttles.unthrottledIps, ip)){
    socketLogic(socket, secure, skynet);
  }else{
    throttles.connection.rateLimit(ip, function (err, limited) {
      if(limited){
        socket.emit('notReady',{error: 'rate limit exceeded ' + ip});
        socket.disconnect();
      }else{
        console.log('io connected');
        socketLogic(socket, secure, skynet);
      }
    });
  }

}



io.on('connection', function (socket) {
  checkConnection(socket, false);
});

if(config.tls){
  ios.on('connection', function (socket) {
    checkConnection(socket, true);
  });
}


var qos = 0;


// create mqtt connection
try {
  // var mqttclient = mqtt.createClient(1883, 'mqtt.skynet.im', mqttsettings);
  var mqttConfig = config.mqtt || {};
  var mqttsettings = {
    keepalive: 1000, // seconds
    protocolId: 'MQIsdp',
    protocolVersion: 3,
    clientId: 'skynet',
    username: 'skynet',
    password: mqttConfig.skynetPass
  };
  //console.log('attempting mqtt connection', mqttsettings);
  var mqttclient = mqtt.createClient(mqttConfig.port || 1883, mqttConfig.host || 'localhost', mqttsettings);
  // var mqttclient = mqtt.createClient(1883, '127.0.0.1', mqttsettings);
  console.log('Skynet connected to MQTT broker');

  setupMqttClient(skynet, mqttclient);
} catch(err){
  console.log('No MQTT server found.', err);
}


// Redirect www subdomain to root domain for https cert
// if(config.tls){
//   server.get(/^\/.*/, function(req, res, next) {
//     if (req.headers.host.match(/^www/) !== null) {
//       // return res.redirect("https://" + req.headers.host.replace(/www\./i, "") + req.url);
//       res.send(302, "https://" + req.headers.host.replace(/www\./i, "") + req.url);
//     } else {
//       return next;
//     }
//   });
// };

// Integrate coap
var coap       = require('coap'),
    coapRouter = require('./lib/coapRouter'),
    coapServer = coap.createServer(),
    coapConfig = config.coap || {};

setupCoapRoutes(coapRouter, skynet);

coapServer.on('request', coapRouter.process);


// Now, setup both servers in one step
setupRestfulRoutes(server, skynet);

if(config.tls){
  setupRestfulRoutes(https_server, skynet);
}

console.log("\n SSSSS  kk                            tt    ");
console.log("SS      kk  kk yy   yy nn nnn    eee  tt    ");
console.log(" SSSSS  kkkkk  yy   yy nnn  nn ee   e tttt  ");
console.log("     SS kk kk   yyyyyy nn   nn eeeee  tt    ");
console.log(" SSSSS  kk  kk      yy nn   nn  eeeee  tttt ");
console.log("                yyyyy                         ");
console.log('\nSkynet %s environment loaded... ', app.environment);

// Start our restful servers to listen on the appropriate ports

coapPort = coapConfig.port || 5683;
coapHost = coapConfig.host || 'localhost';

// Passing in null for the host responds to any request on server
// coapServer.listen(coapPort, coapHost, function () {
// coapServer.listen(coapPort, null, function () {
coapServer.listen(coapPort, function () {
  console.log('coap listening at coap://' + coapHost + ':' + coapPort);
});

server.listen(process.env.PORT || config.port, function() {
  console.log('%s listening at %s', server.name, server.url);
});

if(config.tls){
  https_server.listen(process.env.SSLPORT || config.tls.sslPort, function() {
    console.log('%s listening at %s', https_server.name, https_server.url);
  });
}
