/* Setup command line parsing and options
 * See: https://github.com/visionmedia/commander.js
 */
var app = require('commander');
var tokenthrottle = require("tokenthrottle");

var redis = require('./lib/redis');
var getUuid = require('./lib/getUuid');
var bindSocket = require('./lib/bindSocket');
var authDevice = require('./lib/authDevice');
var fs = require('fs');
var gatewayConfig = require('./lib/gatewayConfig');

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

var _ = require('lodash');
var config = require('./config');
var restify = require('restify');
var socketio = require('socket.io');
var JSONStream = require('JSONStream');
var nstatic = require('node-static');

var securityImpl = require('./lib/getSecurityImpl');

var mqtt = require('mqtt'),
  qos = 0;
var mqttsettings = {
  keepalive: 1000, // seconds
  protocolId: 'MQIsdp',
  protocolVersion: 3,
  clientId: 'skynet'
};

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
};




// create mqtt connection
try {
  // var mqttclient = mqtt.createClient(1883, 'mqtt.skynet.im', mqttsettings);
  var mqttclient = mqtt.createClient(1883, 'localhost', mqttsettings);
  // var mqttclient = mqtt.createClient(1883, '127.0.0.1', mqttsettings);
  console.log('Skynet connected to MQTT broker');


} catch(err){
  console.log('No MQTT server found.');
}

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

var io = socketio.listen(server);
if(config.redis){
  io.configure(function() {
    return io.set("store", redis.createIoStore());
  });
}

if(config.tls){
  var ios = socketio.listen(https_server);

  // TODO: Figure out why secure socket.io doesn't log to REDIS
  // if(config.redis){
    // ios.configure(function() {
    //   return ios.set("store", redis.createIoStore());
    // });
  // };
}

server.use(restify.acceptParser(server.acceptable));
server.use(restify.queryParser());
server.use(restify.bodyParser());
server.use(restify.CORS());

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
      socketServer.sockets.socket(device.socketid).emit('message', msg, function(results){
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



function handleUpdate(fromUuid, data, fn){

  require('./lib/whoAmI')(data.uuid, false, function(check){

    if(check.error){
      return fn(check);
    }

    if(securityImpl.canUpdate(fromUuid, check)){
      require('./lib/updateDevice')(data.uuid, data, function(results){
        console.log('update results', results);

        require('./lib/whoAmI')(fromUuid, false, function(check){
          results.fromUuid = check;
          require('./lib/logEvent')(401, results);
        });

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

function sendMessage(fromUuid, data, fn){

  console.log("sendMessage() from", fromUuid, 'data', data);

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
        mqttclient.publish(fromUuid + '_bc', JSON.stringify(data), {qos:qos});
      }

      require('./lib/logEvent')(300, data);

    } else {

      if(devices){

        if( typeof devices === 'string' ) {
          devices = [ devices ];
        }

        devices.forEach( function(device) {

          if (device.length > 35){

            //check devices are valid
            require('./lib/whoAmI')(device, false, function(check){
              var clonedMsg = cloneMessage(data, device, fromUuid);
              console.log('device check:', check);
              if(!check.error){
                if(securityImpl.canSend(fromUuid, check)){

                  if(check.phoneNumber){
                    // SMS handler
                    console.log("Sending SMS to", check.phoneNumber);
                    require('./lib/sendSms')(device, JSON.stringify(clonedMsg.payload), function(sms){
                      console.log('Sent SMS!', device, check.phoneNumber);
                    });
                  }
                  else if(check.type == 'octobluMobile'){
                    // Push notification handler
                    console.log("Sending Push Notification to", check.uuid);
                    require('./lib/sendPushNotification')(check, JSON.stringify(clonedMsg.payload), function(push){
                      console.log('Sent Push Notification!', device);
                    });
                  }
                  else if(check.protocol == "mqtt"){
                    // MQTT handler
                    console.log('sending mqtt', device);
                    mqttclient.publish(device, JSON.stringify(clonedMsg), {qos:qos});
                  }
                  else{
                    // Websocket handler
                    if(fn && devices.length == 1 ){
                      console.log('sending with callback to: ', device);
                      sendToSocket(check, clonedMsg, fn);
                    }else{
                      sendToSocket(check, clonedMsg, null);
                    }
                  }

                }else{
                  clonedMsg.UNAUTHORIZED=true; //for logging
                  console.log('unauthorized send attempt from', fromUuid, 'to', device);
                }

              }else{
                clonedMsg.INVALID_DEVICE=true; //for logging
                console.log('send attempt on invalid device from', fromUuid, 'to', device);
              }

              var logMsg = _.clone(clonedMsg);
              logMsg.toUuid = check; // add to device object to message for logging
              require('./lib/logEvent')(300, logMsg);

            });

          }

        });

      }

    }

}

function checkConnection(socket, secure){
  var ip = socket.handshake.address.address;
  //console.log(ip);
  throttles.connection.rateLimit(ip, function (err, limited) {
    if(limited){
      socket.emit('notReady',{error: 'rate limit exceeded ' + ip});
      socket.disconnect();
    }else{
      console.log('io connected');
      socketLogic(socket, secure);
    }
  });
}

io.sockets.on('connection', function (socket) {
  checkConnection(socket, false);
});

if(config.tls){
  ios.sockets.on('connection', function (socket) {
    checkConnection(socket, true);
  });
}

function socketLogic (socket, secure){
  console.log('socket connected...');
  var ipAddress = socket.handshake.address.address;

  // socket.limiter = new RateLimiter(1, "second", true);

  console.log('Websocket connection detected. Requesting identification from socket id: ', socket.id);
  require('./lib/logEvent')(100, {"socketid": socket.id, "protocol": "websocket"});

  socket.emit('identify', { socketid: socket.id });
  socket.on('identity', function (data) {
    console.log('identity received', data);
    data["socketid"] = socket.id;
    data["ipAddress"] = ipAddress;
    data["secure"] = secure;
    if(data.protocol == undefined){
      data["protocol"] = "websocket";
    }
    console.log('Identity received: ', JSON.stringify(data));
    // require('./lib/logEvent')(101, data);
    require('./lib/updateSocketId')(data, function(auth){
      if (auth.status == 201){

        if(data.uuid){
          socket.uuid = data.uuid;
          socket.emit('ready', {"api": "connect", "status": auth.status, "socketid": socket.id, "uuid": data.uuid, "token": data.token});
          // Have device join its uuid room name so that others can subscribe to it
          console.log('subscribe: ' + data.uuid);
          //make sure not in there already:
          try{
            socket.leave(data.uuid);
          }catch(lexp){
            console.log('error leaving room', lexp);
          }
          socket.join(data.uuid);
        } else {
          socket.uuid = auth.uuid;
          socket.emit('ready', {"api": "connect", "status": auth.status, "socketid": socket.id, "uuid": auth.uuid, "token": auth.token});
          // Have device join its uuid room name so that others can subscribe to it
          console.log('subscribe: ' + auth.uuid);
          //make sure not in there already:
          try{
            socket.leave(auth.uuid);
          }catch(lexp){
            console.log('error leaving room', lexp);
          }
          socket.join(auth.uuid);
        }

      } else {
        socket.emit('notReady', {"api": "connect", "status": auth.status, "uuid": data.uuid});
      }

      require('./lib/whoAmI')(data.uuid, false, function(results){
        data.auth = auth;
        // results._id.toString();
        // delete results._id;
        data.fromUuid = results;
        require('./lib/logEvent')(101, data);
      });

    });
  });

  socket.on('disconnect', function (data) {
    console.log('Presence offline for socket id: ', socket.id);
    require('./lib/updatePresence')(socket.id);
    // Emit API request from device to room for subscribers
    getUuid(socket, function(err, uuid){
      if(err){ return; }
      require('./lib/whoAmI')(uuid, false, function(results){
        // results._id.toString();
        // delete results_id;

        require('./lib/logEvent')(102, {"api": "disconnect", "socketid": socket.id, "uuid": uuid, "fromUuid": results});
      });

    });

  });

  // Is this API still needed with MQTT?
  socket.on('subscribe', function(data, fn) {
    if(data.uuid && data.uuid.length > 30 && !data.token){
      //no token provided, attempt to only listen for public broadcasts FROM this uuid
      require('./lib/whoAmI')(data.uuid, false, function(results){
        if(results.error){
          fn(results);
        }else{
          socket.join(data.uuid + "_bc");
          fn({"api": "subscribe", "result": true});
        }


        data.toUuid = results;
        require('./lib/logEvent')(204, data);

      });

    }else{
      //token provided, attempt to listen to any broadcast FOR this uuid
      authDevice(data.uuid, data.token, function(auth){
        if (auth.authenticate == true){
          console.log('joining room ', data.uuid);
          socket.join(data.uuid);

          // Emit API request from device to room for subscribers
          getUuid(socket, function(err, uuid){
            if(err){ return; }
            var results = {"api": "subscribe", "socketid": socket.id, "fromUuid": uuid, "toUuid": data.uuid};

            require('./lib/whoAmI')(uuid, false, function(fromCheck){
              require('./lib/whoAmI')(data.uuid, false, function(toCheck){
                data.auth = auth;

                data.fromUuid = fromCheck;
                data.toUuid = toCheck;
                require('./lib/logEvent')(204, data);
              });
            });


            try{
              fn(results);

            } catch (e){
              console.log(e);
            }

          });

        } else {
          console.log('subscribe failed for room ', data.uuid);

          var results = {"api": "subscribe", "uuid": data.uuid, "result": false};
          // socket.broadcast.to(uuid).emit('message', results);

          require('./lib/logEvent')(204, results);

          console.log(results);
          try{
            fn(results);

          } catch (e){
            console.log(e);
          }

        }

      });
    }

  });

  // Is this API still needed with MQTT?
  socket.on('unsubscribe', function(data, fn) {
      console.log('leaving room ', data.uuid);
      socket.leave(data.uuid);
      // Emit API request from device to room for subscribers
      getUuid(socket, function(err, uuid){
        if(err){ return; }
        var results = {"api": "unsubscribe", "socketid": socket.id, "uuid": uuid};
        // socket.broadcast.to(uuid).emit('message', results);

        require('./lib/whoAmI')(uuid, false, function(fromCheck){
          require('./lib/whoAmI')(data.uuid, false, function(toCheck){
            data.fromUuid = fromCheck;
            data.toUuid = toCheck;
            require('./lib/logEvent')(205, data);
          });
        });


        try{
          fn(results);
        } catch (e){
          console.log(e);
        }

      });
  });

  // APIs
  socket.on('status', function (fn) {

    throttles.query.rateLimit(socket.id, function (err, limited) {
      if(limited){
        console.log('status throttled', socket.id);
      }else{

        // Emit API request from device to room for subscribers
        getUuid(socket, function(err, uuid){
          if(err){ return; }
          // socket.broadcast.to(uuid).emit('message', {"api": "status"});

          require('./lib/getSystemStatus')(function(results){
            console.log(results);

            require('./lib/whoAmI')(uuid, false, function(check){
              // check._id.toString();
              // delete check._id;
              results.fromUuid = check;
              require('./lib/logEvent')(200, results);
            });

            try{
              fn(results);

            } catch (e){
              console.log(e);
            }
          });

        });
      }
    });

  });



  socket.on('devices', function (data, fn) {
    throttles.query.rateLimit(socket.id, function (err, limited) {
      if(limited){
        console.log('query throttled', socket.id);
      }else{

        if(!data || (typeof data != 'object')){
          data = {};
        }
        // Emit API request from device to room for subscribers
        getUuid(socket, function(err, uuid){
          if(err){ return; }
          var reqData = data;
          require('./lib/getDevices')(uuid, data, req.connection.remoteAddress, false, function(results){
            console.log(results);

            require('./lib/whoAmI')(uuid, false, function(check){
              results.fromUuid = check;
              require('./lib/logEvent')(403, results);
            });

            try{
              fn(results);

            } catch (e){
              console.log(e);
            }
          });
        });
      }
    });
  });

  socket.on('whoami', function (data, fn) {

    throttles.whoami.rateLimit(socket.id, function (err, limited) {
      if(limited){
        console.log('whoami throttled', socket.id);
      }else{

        if(!data){
          data = "";
        } else {
          data = data.uuid;
        }
        // Emit API request from device to room for subscribers
        getUuid(socket, function(err, uuid){
          if(err){ return; }
          var reqData = data;
          require('./lib/whoAmI')(data, false, function(results){

            require('./lib/whoAmI')(uuid, false, function(check){
              // delete check._id;
              results.fromUuid = check;
              require('./lib/logEvent')(500, results);
            });

            try{
              fn(results);
            } catch (e){
              console.log(e);
            }
          });
        });

      }
    });

  });

  //tell skynet to forward plain text to another socket
  socket.on('bindSocket', function (data, fn) {

    var target;

    function bindReply(result){
      if(result == 'ok' || (result && result.result == 'ok')){
        bindSocket.connect(socket.id, target.socketid, function(err, val){
          if(err){
            fn(err);
          }else{
            fn(result);
          }
        });

      }else{
        fn(result);
      }
    }

    if(!data){
      return fn({error: 'invalid request'});
    }

    getUuid(socket, function(err, uuid){
      if(err){ return fn({error: 'invalid client'}); }

      require('./lib/whoAmI')(data.uuid, false, function(check){
        if(!check.error){
          target = check;
          if(target.socketid && securityImpl.canSend(uuid, target)){
            if(target.secure && config.tls){
              ios.sockets.socket(target.socketid).emit("bindSocket", {fromUuid: uuid}, bindReply);
            } else {
              io.sockets.socket(target.socketid).emit("bindSocket", {fromUuid: uuid}, bindReply);
            }
          }else{
            console.log('client target',uuid, target);
            return fn({error: 'invalid client or target'});
          }
        }
      });

    });
  });

  socket.on('register', function (data, fn) {
    if(!data){
      data = {};
    }
    data.socketid = socket.id;

    require('./lib/register')(data, function(results){

      require('./lib/whoAmI')(data.uuid, false, function(check){

        results.fromUuid = check;

        if(!check.error){
          socket.uuid = check.uuid;
        }

        require('./lib/logEvent')(400, results);
      });



      try{
        fn(results);

      } catch (e){
        console.log(e);
      }
    });

  });

  socket.on('update', function (data, fn) {
    if(!data){
      data = {};
    }
    // Emit API request from device to room for subscribers
    getUuid(socket, function(err, uuid){
      if(err){ return; }

      handleUpdate(uuid, data, fn);

    });
  });

  socket.on('unregister', function (data, fn) {
    if(!data){
      data = {};
    }
    // Emit API request from device to room for subscribers
    getUuid(socket, function(err, uuid){
      if(err){ return; }
      var reqData = data;
      require('./lib/unregister')(data.uuid, data, function(results){
        // results._id.toString();
        // delete results._id;

        console.log(results);

        require('./lib/whoAmI')(uuid, false, function(check){
          // check._id.toString();
          // delete check._id;
          results.fromUuid = check;
          require('./lib/logEvent')(402, results);
        });

        try{
          fn(results);

        } catch (e){
          console.log(e);
        }
      });
    });
  });

  socket.on('events', function(data, fn) {
    authDevice(data.uuid, data.token, function(auth){

      // Emit API request from device to room for subscribers
      getUuid(socket, function(err, uuid){
        if(err){ return; }
        var reqData = data;
        reqData["api"] = "events";

        if (auth.authenticate == true){

          require('./lib/getEvents')(data.uuid, function(results){
            console.log(results);

            try{
              fn(results);
            } catch (e){
              console.log(e);
            }

          });

        } else {
          console.log('UUID not found or invalid token ', data.uuid);

          var results = {"api": "events", "result": false};

          console.log(results);
          try{
            fn(results);

          } catch (e){
            console.log(e);
          }

        }

      });

    });
  });


  socket.on('authenticate', function(data, fn) {
    authDevice(data.uuid, data.token, function(auth){

      if (auth.authenticate == true){
        var results = {"uuid": data.uuid, "authentication": true};

        socket.emit('ready', {"api": "connect", "status": 201, "socketid": socket.id, "uuid": data.uuid});
        console.log('subscribe: ' + data.uuid);
        socket.join(data.uuid);

        try{
          fn(results);
        } catch (e){
          console.log(e);
        }

      } else {
        var results = {"uuid": data.uuid, "authentication": false};
        try{
          fn(results);
        } catch (e){
          console.log(e);
        }

      };

      require('./lib/whoAmI')(data.uuid, false, function(check){
        // check._id.toString();
        // delete check._id;
        results.toUuid = check;
        require('./lib/logEvent')(102, results);
      });


    });
  });

  socket.on('data', function (messageX, fn) {

    throttles.data.rateLimit(socket.id, function (err, limited) {
      if(limited){
        console.log('data throttled', socket.id);
      }else{
        var data = messageX;

        authDevice(data.uuid, data.token, function(auth){

          getUuid(socket, function(err, uuid){
            if(err){ return; }

            delete data.token;
            var reqData = data;
            reqData["api"] = "data";

            if (auth.authenticate == true){

              require('./lib/logData')(data, function(results){
                console.log(results);

                // Send messsage regarding data update
                var message = {};
                message.payload = data;
                message.devices = data.uuid;

                console.log('message: ' + JSON.stringify(message));

                sendMessage(uuid, message);


                try{
                  fn(results);
                } catch (e){
                  console.log(e);
                }

              });

            } else {
              console.log('UUID not found or invalid token ', data.uuid);

              var results = {"api": "data", "result": false};

              console.log(results);
              try{
                fn(results);
              } catch (e){
                console.log(e);
              }
            }
          });
        });

      }
    });
  });



  socket.on('gatewayConfig', function(data, fn) {
    gatewayConfig(io, data, fn);
  });


  socket.on('message', function (messageX, fn) {
    // socket.limiter.removeTokens(1, function(err, remainingRequests) {
    throttles.message.rateLimit(socket.id, function (err, limited) {
      var message = messageX;

      if (limited) {
        // response.writeHead(429, {'Content-Type': 'text/plain;charset=UTF-8'});
        // response.end('429 Too Many Requests - your IP is being rate limited');

        // TODO: Emit rate limit exceeded message
        console.log("Rate limit exceeded for socket:", socket.id);
        console.log("message", message);

      } else {
        console.log("Sending message for socket:", socket.id, message);

        if(!message){
          return;
        } else if (typeof message == 'string'){

          bindSocket.getTarget(socket.id, function(err, target){
            if(target){

              socket._unboundTarget = 0;
              // Determine is socket is secure
              getUuid(socket, function(err, uuid){
                require('./lib/whoAmI')(uuid, false, function(check){

                  if(check.secure){
                    if(config.tls){
                      ios.sockets.socket(target).send(message);
                    }
                  } else {
                    //console.log('socket lookup', io.sockets.socket(target));
                    io.sockets.socket(target).send(message);
                  }

                });
              });

              //async update for TTL
              bindSocket.connect(socket.id, target);
            }else{
              //no longer bound, start checking for unbound repeats
              if(!socket._unboundTarget){
                socket._unboundTarget = 1;
              }else{
                socket._unboundTarget += 1;
              }

              if(socket._unboundTarget > 2){
                console.log('sending unbind message', socket.id);
                socket.emit('unboundSocket', {error : 'unbound from remote uuid'});
                socket._unboundTarget = 0;
              }


            }
          });

        }else{
          // Broadcast to room for pubsub
          getUuid(socket, function(err, uuid){
            message.api = "message";
            var fromUuid = uuid || message.fromUuid || null;
            sendMessage(fromUuid, message, fn);
          });
        }

      }
    });

  });

}

// Handle MQTT Messages
try{
  mqttclient.subscribe('skynet');
  // mqttclient.publish('742401f1-87a4-11e3-834d-670dadc0ddbf', 'Hello mqtt');

  mqttclient.on('message', function (topic, message) {
    // console.log('mqtt message received', topic, message);
    console.log('mqtt message received:', topic);
    console.log(message);
    try{
      message = JSON.parse(message);
    }catch(ex){
      console.log('exception parsing json', ex);
      return;
    }

    // require('./lib/authDevice')(message.uuid, message.token, function(auth){

    //   if (auth.authenticate == true){
    //     //TODO figure out how to rate limit without checking auth
    //     throttle.rateLimit(socket.id.toString(), function (err, limited) {
    //       var messageX = message;
    //       if (limited) {
    //         // TODO: Emit rate limit exceeded message
    //         console.log("Rate limit exceeded for mqtt:", messageX.uuid);
    //         console.log("message", messageX);

    //       } else {
    //         sendMessage(message.uuid, messageX);
    //       }
    //     });

    //   }else{
    //     console.log('invalid attempted mqtt publish', message);
    //   }

    //   var eventData = {devices: topic, message: message};
    //   require('./lib/logEvent')(300, eventData);
    // });

    //add auth and throttling later

    // Determine is socket is secure
    // require('./lib/whoAmI')(message.uuid, false, function(check){
      // if(check.secure){
        // sendMessage(message.fromUuid, message, true);
      // } else {
        sendMessage(message.fromUuid, message);
      // }
    // });


  });
} catch(e){
  console.log('no mqtt server found');
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
    coapConfig = config.coap;

// coap get coap://localhost/status
coapRouter.get('/status', function (req, res) {
  require('./lib/getSystemStatus')(function (data) {
    console.log(data);
    if(data.error) {
      res.statusCode = data.error.code;
      res.json(data.error);
    } else {
      res.json(data);
    }
  });
});


// coap get coap://localhost/ipaddress
coapRouter.get('/ipaddress', function (req, res) {
  res.json({ipAddress: req.rsinfo.address});
});


coapRouter.get('/devices', function (req, res) {
  authDevice(req.params.uuid, req.params.token, function (auth) {
    if (auth.authenticate) {
      require('./lib/getDevices')(req.params.uuid, req.query, null,false, function (data) {
        if(data.error) {
          res.statusCode = data.error.code;
          res.json(data.error);
        } else {
          res.json(data);
        }
      });
    }else{
      res.statusCode = 401;
      res.json({error: 'unauthorized'});
    }
  });


});


coapRouter.post('/devices', function (req, res) {
  req.params['ipAddress'] = req.rsinfo.address
  require('./lib/register')(req.params, function (data) {
    console.log(data);
    if(data.error) {
      res.statusCode = data.error.code;
      res.json(data.error);
    } else {
      res.json(data);
    }

  });
});

// coap post coap://localhost/devices -p "devices=a1634681-cb10-11e3-8fa5-2726ddcf5e29&payload=test"
coapRouter.get('/whoAmI/:uuid', function (req, res) {
  require('./lib/whoAmI')(req.params.uuid, false, function (data) {
    console.log(data);
    if(data.error) {
      res.statusCode = data.error.code;
      res.json(data.error);
    } else {
      res.json(data);
    }

  });
});

// coap get coap://localhost/devices/a1634681-cb10-11e3-8fa5-2726ddcf5e29
coapRouter.get('/devices/:uuid', function (req, res) {
  require('./lib/whoAmI')(req.params.uuid, false, function (data) {
    console.log(data);
    if(data.error) {
      res.statusCode = data.error.code;
      res.json(data.error);
    } else {
      res.json(data);
    }

  });
});


coapRouter.put('/devices/:uuid', function (req, res) {

  authDevice(req.params.uuid, req.params.token, function (auth) {
    if (auth.authenticate) {
      handleUpdate(req.params.uuid, req.params, function(result){
        if(result.error){
          res.statusCode = result.error.code;
          res.json(result.error);
        }else{
          res.json(result);
        }
      });
    }else{
      res.statusCode = 401;
      res.json({error: 'unauthorized'});
    }
  });
});


coapRouter.delete('/devices/:uuid', function (req, res) {
  require('./lib/unregister')(req.params.uuid, req.params, function (data) {
    console.log(data);
    if(data.error) {
      res.statusCode = data.error.code;
      res.json(data.error);
    } else {
      res.json(data);
    }
  });
});


coapRouter.get('/mydevices/:uuid', function (req, res) {
  authDevice(req.params.uuid, req.query.token, function (auth) {
    if (auth.authenticate == true) {
      req.query.owner = req.params.uuid;
      delete req.query.token;
      require('./lib/getDevices')(req.params.uuid, req.query, null, true, function (data) {
        console.log(data);
        if(data.error) {
          res.statusCode = data.error.code;
          res.json(data.error);
        } else {
          res.json(data);
        }
      });
    } else {
      console.log("Device not found or token not valid");
      res.statusCode = 404;
      res.json({error: "Device not found or token not valid"});

    }
  });
});


// coap get coap://localhost/authenticate/81246e80-29fd-11e3-9468-e5f892df566b?token=5ypy4rurayktke29ypbi30kcw5ovfgvi
coapRouter.get('/authenticate/:uuid', function(req, res){
  authDevice(req.params.uuid, req.query.token, function(auth){
    if (auth.authenticate == true){
      res.json({uuid:req.params.uuid, authentication: true});
    } else {
      regdata = {
        "error": {
          "message": "Device not found or token not valid",
          "code": 404
        }
      };
      res.statusCode = regdata.error.code;
      res.json({code: regdata.error.code, payload: {uuid:req.params.uuid, authentication: false}});

    }
  });
});


coapRouter.get('/gateway/:uuid', function (req, res) {
  require('./lib/whoAmI')(req.params.uuid, false, function (data) {
    console.log(data);
    res.statusCode = 302;
    if(data.error) {
      res.json({
        'location': 'http://skynet.im'
      });
    } else {
      res.json({
        'location': 'http://' + data.localhost + ":" + data.port
      });
    }
  });
});


// echo '{"uuid": "ad698900-2546-11e3-87fb-c560cb0ca47b", "token": "g6jmsla14j2fyldi7hqijbylwmrysyv5", "method": "getSubdevices"}' | coap post 'coap://localhost:3000/gatewayConfig'
coapRouter.post('/gatewayConfig', function(req, res){
  var body;
  try {
    body = JSON.parse(req.body);
  } catch(err) {
    console.log('error parsing', err, req.body);
    body = {};
  }

  gatewayConfig(io, body, function(result){
    if(result && result.error && result.error.code){
      res.statusCode = result.error.code;
      res.json(result.error);
    }else{
      res.json(result);
    }
  });

  require('./lib/logEvent')(300, body);
});


// coap get coap://localhost/events/196798f1-b5d8-11e3-8c93-45a0c0308eaa -p "token=00cpk8akrmz8semisbebhe0358livn29"
coapRouter.get('/events/:uuid', function (req, res) {
  console.log(req);
  authDevice(req.params.uuid, req.params.token, function (auth) {
    if (auth.authenticate == true) {
      require('./lib/getEvents')(req.params.uuid, function (data) {
        console.log(data);
      if(data.error){
        res.statusCode = data.error.code;
        res.json(data.error);
      } else {
        res.json(data);
      }
      });
    } else {
      console.log("Device not found or token not valid");
      res.statusCode = 404;
      res.json({error: "Device not found or token not valid"});
    }
  });
});


// coap post coap://localhost/data/196798f1-b5d8-11e3-8c93-45a0c0308eaa -p "token=00cpk8akrmz8semisbebhe0358livn29&temperature=43"
coapRouter.post('/data/:uuid', function(req, res){
  authDevice(req.params.uuid, req.query.token, function(auth){
    if (auth.authenticate == true){

      delete req.params.token;

      if(req.connection){
        req.params['ipAddress'] = req.connection.remoteAddress;
      }
      require('./lib/logData')(req.params, function(data){
        console.log(data);
        if(data.error){
          res.statusCode = data.error.code;
          res.json(data.error);
        } else {

          // Send messsage regarding data update
          var message = {};
          message.payload = req.params;
          message.devices = req.params.uuid;

          console.log('message: ' + JSON.stringify(message));

          sendMessage(message.devices, message);

          res.json(data);
        }
      });

    } else {
      regdata = {
        "error": {
          "message": "Device not found or token not valid",
          "code": 404
        }
      };
      res.statusCode = regdata.error.code;
      res.json(regdata.error.code, {uuid:req.params.uuid, authentication: false});
    }
  });

});


// coap get coap://localhost/data/196798f1-b5d8-11e3-8c93-45a0c0308eaa -p "token=00cpk8akrmz8semisbebhe0358livn29&limit=1"
coapRouter.get('/data/:uuid', function(req, res){
  console.log(req.params);
  console.log(req.query);

  authDevice(req.params.uuid, req.query.token, function(auth){
    if (auth.authenticate == true){
      if(req.query.stream){

        var foo = JSONStream.stringify(open='\n', sep=',\n', close='\n\n');
        foo.on("data", function(data){
          console.log('DATA', data);
          return data
        });

        require('./lib/getData')(req)
          .pipe(foo)
          .pipe(res);

      } else {
        req.query = req.params;
        require('./lib/getData')(req, function(data){
          console.log(data);
          if(data.error){
            res.statusCode = data.error.code;
            res.json(data.error);
          } else {
            res.json(data);
          }
        });
      }


    } else {
      console.log("Device not found or token not valid");
      res.statusCode = 404;
      res.json({error: "Device not found or token not valid"});

    }
  });
});

// coap post coap://localhost/messages -p "devices=a1634681-cb10-11e3-8fa5-2726ddcf5e29&payload=test"
coapRouter.post('/messages', function (req, res, next) {
  try {
    var body = JSON.parse(req.payload);
  } catch(err) {
    var body = req.payload;
  }
  if (body.devices == undefined){
    try {
      var body = JSON.parse(req.params);
    } catch(err) {
      var body = req.params;
    }
  }
  var devices = body.devices;
  var message = {};
  message.payload = body.payload;
  message.devices = body.devices;

  console.log('devices: ' + devices);
  console.log('payload: ' + JSON.stringify(message));

  sendMessage(devices, message);
  res.json({devices:devices, payload: body.payload});

  require('./lib/logEvent')(300, message);

});

coapRouter.get('/subscribe/:uuid', function (req, res) {
  authDevice(req.params.uuid, req.query.token, function (auth) {
    console.log('auth', auth);
    if (auth.authenticate == true) {
      var foo = JSONStream.stringify(open='\n', sep=',\n', close='\n\n');

      require('./lib/subscribe')(req.params.uuid)
        .pipe(foo)
        .pipe(res);

    } else {
      console.log("Device not found or token not valid");
      res.statusCode = 404;
      res.json({error: "Device not found or token not valid"});
    }
  });
});


coapServer.on('request', coapRouter.process);

// Integrate restful routes
function setupRestfulRoutes (server) {
  // curl http://localhost:3000/status
  server.get('/status', function(req, res){
    res.setHeader('Access-Control-Allow-Origin','*');
    require('./lib/getSystemStatus')(function(data){
      console.log(data);
      // io.sockets.in(req.params.uuid).emit('message', data)
      if(data.error){
        res.json(data.error.code, data);
      } else {
        res.json(data);
      }

    });
  });

  // curl http://localhost:3000/ipaddress
  server.get('/ipaddress', function(req, res){
    res.setHeader('Access-Control-Allow-Origin','*');
    res.json({ipAddress: req.connection.remoteAddress});
  });



  // curl http://localhost:3000/devices
  // curl http://localhost:3000/devices?key=123
  // curl http://localhost:3000/devices?online=true
  // server.get('/devices/:uuid', function(req, res){
  server.get('/devices', function(req, res){
    res.setHeader('Access-Control-Allow-Origin','*');
    // authDevice(req.params.uuid, req.query.token, function (auth) {
      // if (auth.authenticate) {
        require('./lib/getDevices')(req.params.uuid, req.query, req.connection.remoteAddress, false, function(data){
          if(data.error){
            res.json(data.error.code, data);
          }else{
            res.json(data);
          }
        });
      // }else{
        // res.json(401, {error: 'unauthorized'});
      // }
    // });

  });

  server.get('/devices/:uuid', function(req, res){
    res.setHeader('Access-Control-Allow-Origin','*');
    authDevice(req.params.uuid, req.query.token, function (auth) {
      if (auth.authenticate) {
        require('./lib/getDevices')(req.params.uuid, req.query, req.connection.remoteAddress, false, function(data){
          if(data.error){
            res.json(data.error.code, data);
          }else{
            res.json(data);
          }
        });
      }else{
        res.json(401, {error: 'unauthorized'});
      }
    });
  });


  // curl http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
  server.get('/whoAmI/:uuid', function(req, res){

    res.setHeader('Access-Control-Allow-Origin','*');
    require('./lib/whoAmI')(req.params.uuid, false, function(data){
      console.log(data);
      // io.sockets.in(req.params.uuid).emit('message', data)
      if(data.error){
        res.json(data.error.code, data);
      } else {
        res.json(data);
      }

    });
  });

  // curl http://localhost:3000/gateway/01404680-2539-11e3-b45a-d3519872df26
  server.get('/gateway/:uuid', function(req, res){
    // res.setHeader('Access-Control-Allow-Origin','*');
    require('./lib/whoAmI')(req.params.uuid, false, function(data){
      console.log(data);
      if(data.error){
        res.writeHead(302, {
          'location': 'http://skynet.im'
        });
      } else {
        res.writeHead(302, {
          'location': 'http://' + data.localhost + ":" + data.port
        });
      }
      res.end();

    });
  });


  // curl -X POST -d "name=arduino&description=this+is+a+test" http://localhost:3000/devices
  server.post('/devices', function(req, res){
    res.setHeader('Access-Control-Allow-Origin','*');
    req.params['ipAddress'] = req.connection.remoteAddress
    require('./lib/register')(req.params, function(data){
      console.log(data);
      // io.sockets.in(data.uuid).emit('message', data)
      if(data.error){
        res.json(data.error.code, data);
      } else {
        res.json(data);
      }

    });
  });

  // curl -X PUT -d "token=123&online=true&temp=hello&temp2=world" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
  // curl -X PUT -d "token=123&online=true&temp=hello&temp2=null" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
  // curl -X PUT -d "token=123&online=true&temp=hello&temp2=" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
  // curl -X PUT -d "token=123&myArray=[1,2,3]" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
  // curl -X PUT -d "token=123&myArray=4&action=push" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
  server.put('/devices/:uuid', function(req, res){
    res.setHeader('Access-Control-Allow-Origin','*');
    authDevice(req.params.uuid, req.query.token, function (auth) {
      if (auth.authenticate) {
        handleUpdate(req.params.uuid, req.params, function(result){
          if(result.error){
            res.json(result.error.code, result);
          }else{
            res.json(result);
          }
        });
      }else{
        res.json(401, {error: 'unauthorized'});
      }
    });

  });

  // curl -X DELETE -d "token=123" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
  server.del('/devices/:uuid', function(req, res){
    res.setHeader('Access-Control-Allow-Origin','*');
    require('./lib/unregister')(req.params.uuid, req.params, function(data){
      console.log(data);
      // io.sockets.in(req.params.uuid).emit('message', data)
      if(data.error){
        res.json(data.error.code, data);
      } else {
        res.json(data);
      }
    });
  });

  // Returns all devices owned by authenticated user
  // curl -X GET http://localhost:3000/mydevices/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc?token=qirqglm6yb1vpldixflopnux4phtcsor
  server.get('/mydevices/:uuid', function(req, res){
    res.setHeader('Access-Control-Allow-Origin','*');
    authDevice(req.params.uuid, req.query.token, function(auth){
      if (auth.authenticate){
        req.query.owner = req.params.uuid;
        delete req.query.token;
        require('./lib/getDevices')(req.params.uuid, req.query, req.connection.remoteAddress, true, function(data){
          console.log(data);
          // io.sockets.in(req.params.uuid).emit('message', data)
          if(data.error){
            res.json(data.error.code, data);
          } else {
            res.json(data);
          }
        });
      } else {
        console.log("/mydevices Device not found or token not valid");
        res.json(401, {error: "Device not found or token not valid"});
      }
    });
  });


  // curl -X GET http://localhost:3000/events/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc?token=qirqglm6yb1vpldixflopnux4phtcsor
  server.get('/events/:uuid', function(req, res){
    res.setHeader('Access-Control-Allow-Origin','*');
    authDevice(req.params.uuid, req.query.token, function(auth){
      if (auth.authenticate){
        require('./lib/getEvents')(req.params.uuid, function(data){
          console.log(data);
          // io.sockets.in(req.params.uuid).emit('message', data)
        if(data.error){
          res.json(data.error.code, data);
        } else {
          res.json(data);
        }
        });
      } else {
        console.log("/events Device not found or token not valid");
        res.json(401, {error: "Device not found or token not valid"});
      }
    });
  });

  // curl -X GET http://localhost:3000/events/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc?token=qirqglm6yb1vpldixflopnux4phtcsor
  server.get('/subscribe/:uuid', function(req, res){
    res.setHeader('Access-Control-Allow-Origin','*');
    authDevice(req.params.uuid, req.query.token, function(auth){
      if (auth.authenticate){

        var foo = JSONStream.stringify(open='\n', sep=',\n', close='\n\n');
        foo.on("data", function(data){
          console.log(data);
          data = data + '\r\n';
        })
        require('./lib/subscribe')(req.params.uuid)
          .pipe(foo)
          .pipe(res);

      } else {
        console.log("/subscribe Device not found or token not valid");
        res.json(401, {error: "Device not found or token not valid"});

      }
    });
  });

  // curl -X GET http://localhost:3000/authenticate/81246e80-29fd-11e3-9468-e5f892df566b?token=5ypy4rurayktke29ypbi30kcw5ovfgvi
  server.get('/authenticate/:uuid', function(req, res){
    res.setHeader('Access-Control-Allow-Origin','*');
    authDevice(req.params.uuid, req.query.token, function(auth){
      if (auth.authenticate){
        res.json({uuid:req.params.uuid, authentication: true});
      } else {
        regdata = {
          "error": {
            "message": "Device not found or token not valid",
            "code": 404
          }
        };
        res.json(regdata.error.code, {uuid:req.params.uuid, authentication: false});

      }
    });
  });


  // curl -X POST -d '{"devices": "all", "payload": {"yellow":"off"}}' http://localhost:3000/messages
  // curl -X POST -d '{"devices": ["ad698900-2546-11e3-87fb-c560cb0ca47b","2f3113d0-2796-11e3-95ef-e3081976e170"], "payload": {"yellow":"off"}}' http://localhost:3000/messages
  // curl -X POST -d '{"devices": "ad698900-2546-11e3-87fb-c560cb0ca47b", "payload": {"yellow":"off"}}' http://localhost:3000/messages
  server.post('/messages', function(req, res, next){
    res.setHeader('Access-Control-Allow-Origin','*');
    try {
      var body = JSON.parse(req.body);
    } catch(err) {
      var body = req.body;
    }
    if (body.devices == undefined){
      try {
        var body = JSON.parse(req.params);
      } catch(err) {
        var body = req.params;
      }
    }
    var devices = body.devices;
    var message = {};
    message.payload = body.payload;
    message.devices = body.devices;

    console.log('devices: ' + devices);
    console.log('payload: ' + JSON.stringify(message));

    sendMessage(devices, message);
    res.json({devices:devices, payload: body.payload});

    require('./lib/logEvent')(300, message);

  });

  // curl -X POST -d '{"uuid": "ad698900-2546-11e3-87fb-c560cb0ca47b", "token": "g6jmsla14j2fyldi7hqijbylwmrysyv5", "method": "getSubdevices"' http://localhost:3000/gatewayConfig
  server.post('/gatewayConfig', function(req, res, next){
    res.setHeader('Access-Control-Allow-Origin','*');
    var body;
    try {
      body = JSON.parse(req.body);
    } catch(err) {
      console.log('error parsing', err, req.body);
      body = {};
    }

    gatewayConfig(io, body, function(result){
      if(result && result.error && result.error.code){
        res.json(result.error.code, result);
      }else{
        res.json(result);
      }
    });

    require('./lib/logEvent')(300, body);

  });

  // curl -X GET -d "token=123" http://localhost:3000/inboundsms
  server.get('/inboundsms', function(req, res){

    res.setHeader('Access-Control-Allow-Origin','*');
    console.log(req.params);
    // { To: '17144625921',
    // Type: 'sms',
    // MessageUUID: 'f1f3cc84-8770-11e3-9f8a-842b2b455655',
    // From: '14803813574',
    // Text: 'Test' }
    try{
      var data = JSON.parse(req.params);
    } catch(e){
      var data = req.params;
    }
    var toPhone = data.To;
    var fromPhone = data.From;
    var message = data.Text;

    require('./lib/getPhone')(toPhone, function(uuid){
      console.log(uuid);

      mqttclient.publish(uuid, JSON.stringify(message), {qos:qos});
      // io.sockets.in(uuid).emit('message', {message: message});

      require('./lib/whoAmI')(uuid, false, function(check){
        if(check.secure){
          if(config.tls){
            ios.sockets.in(uuid).emit('message', {
              devices: uuid,
              payload: message,
              api: 'message',
              fromUuid: {},
              eventCode: 300
            });
          }
        } else {
          io.sockets.in(uuid).emit('message', {
            devices: uuid,
            payload: message,
            api: 'message',
            fromUuid: {},
            eventCode: 300
          });
        }
      });


      var eventData = {devices: uuid, payload: message}
      require('./lib/logEvent')(301, eventData);
      if(eventData.error){
        res.json(eventData.error.code, eventData);
      } else {
        res.json(eventData);
      }

    });
  });

  // curl -X POST -d "token=123&temperature=78" http://localhost:3000/data/ad698900-2546-11e3-87fb-c560cb0ca47b
  server.post('/data/:uuid', function(req, res){
    res.setHeader('Access-Control-Allow-Origin','*');

    authDevice(req.params.uuid, req.params.token, function(auth){
      if (auth.authenticate == true){

        delete req.params.token;

        req.params['ipAddress'] = req.connection.remoteAddress
        require('./lib/logData')(req.params, function(data){
          console.log(data);
          // io.sockets.in(data.uuid).emit('message', data)
          if(data.error){
            res.json(data.error.code, data);
          } else {

            // Send messsage regarding data update
            var message = {};
            message.payload = req.params;
            message.devices = req.params.uuid;

            console.log('message: ' + JSON.stringify(message));

            sendMessage(message.devices, message);

            res.json(data);
          }
        });

      } else {
        regdata = {
          "error": {
            "message": "Device not found or token not valid",
            "code": 404
          }
        };
        res.json(regdata.error.code, {uuid:req.params.uuid, authentication: false});
      }
    });

  });

  // curl -X GET http://localhost:3000/data/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc?token=qirqglm6yb1vpldixflopnux4phtcsor
  server.get('/data/:uuid', function(req, res){
    res.setHeader('Access-Control-Allow-Origin','*');
    authDevice(req.params.uuid, req.query.token, function(auth){
      if (auth.authenticate){
        if(req.query.stream){

          var foo = JSONStream.stringify(open='\n', sep=',\n', close='\n\n');
          foo.on("data", function(data){
            // data = data.toString() + '\r\n';
            console.log('DATA', data);
            return data
          });
          require('./lib/getData')(req)
            .pipe(foo)
            .pipe(res);

        } else {

          require('./lib/getData')(req, function(data){
            console.log(data);
            if(data.error){
              res.json(data.error.code, data);
            } else {
              res.json(data);
            }
          });
        }


      } else {
        console.log("Device not found or token not valid");
        regdata = {
          "error": {
            "message": "Device not found or token not valid",
            "code": 404
          }
        };
        if(regdata.error){
          res.json(regdata.error.code, regdata);
        } else {
          res.json(regdata);
        }

      }
    });
  });


  // Serve static website
  var file = new nstatic.Server('');
  server.get('/demo/:uuid', function(req, res, next) {
    file.serveFile('/demo.html', 200, {}, req, res);
  });

  server.get('/', function(req, res, next) {
      file.serveFile('/index.html', 200, {}, req, res);
  });

  server.get(/^\/.*/, function(req, res, next) {
      file.serve(req, res, next);
  });

  return server;
}


// Now, setup both servers in one step
setupRestfulRoutes(server);

if(config.tls){
  setupRestfulRoutes(https_server);
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
