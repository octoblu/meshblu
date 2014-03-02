/* Setup command line parsing and options
 * See: https://github.com/visionmedia/commander.js
 */
var app = require('commander');
app
  .option('-e, --environment', 'Set the environment (defaults to development)')
  .parse(process.argv);

console.log(app.environment);
if(!app.environment) app.environment = 'development'; 

var config = require('./config');
var restify = require('restify');
var socketio = require('socket.io');
var nstatic = require('node-static');
var JSONStream = require('JSONStream');

var RedisStore = require('socket.io/lib/stores/redis');
var redis = require('socket.io/node_modules/redis');

var mqtt = require('mqtt'),
  qos = 0;
var mqttsettings = {
  keepalive: 1000, // seconds
  protocolId: 'MQIsdp',
  protocolVersion: 3,
  clientId: 'skynet'
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

// rate per second
var throttle = require("tokenthrottle")({rate: config.rateLimit}); 

// create mqtt connection
try {
  // var mqttclient = mqtt.createClient(1883, 'mqtt.skynet.im', mqttsettings);
  var mqttclient = mqtt.createClient(1883, 'localhost', mqttsettings);
  // var mqttclient = mqtt.createClient(1883, '127.0.0.1', mqttsettings);
  console.log('Skynet connected to MQTT broker');


} catch(err){
  console.log('No MQTT server found.');
}

// Setup RedisStore for socket.io scaling
var options, pub, store, sub;
options = {
  parser: "javascript"
};
pub = redis.createClient(config.redisPort, config.redisHost, options);
sub = redis.createClient(config.redisPort, config.redisHost, options);
store = redis.createClient(config.redisPort, config.redisHost, options);
pub.auth(config.redisPassword, function(err) {
  if (err) {
    throw err;
  }
});
sub.auth(config.redisPassword, function(err) {
  if (err) {
    throw err;
  }
});
store.auth(config.redisPassword, function(err) {
  if (err) {
    throw err;
  }
});

var server = restify.createServer();
var io = socketio.listen(server);

io.configure(function() {
  return io.set("store", new RedisStore({
    redisPub: pub,
    redisSub: sub,
    redisClient: store
  }));
});

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

io.sockets.on('connection', function (socket) {

  var ipAddress = socket.handshake.address.address;

  // socket.limiter = new RateLimiter(1, "second", true);

  console.log('Websocket connection detected. Requesting identification from socket id: ' + socket.id.toString());
  require('./lib/logEvent')(100, {"socketId": socket.id.toString(), "protocol": "websocket"});
  
  socket.emit('identify', { socketid: socket.id.toString() });
  socket.on('identity', function (data) {
    data["socketid"] = socket.id.toString();
    data["ipAddress"] = ipAddress;
    if(data.protocol == undefined){
      data["protocol"] = "websocket";
    }
    console.log('Identity received: ' + JSON.stringify(data));
    require('./lib/logEvent')(101, data);
    require('./lib/updateSocketId')(data, function(auth){
      if (auth.status == 201){

        if(data.uuid){
          socket.emit('ready', {"api": "connect", "status": auth.status, "socketid": socket.id.toString(), "uuid": data.uuid, "token": data.token});
          // Have device join its uuid room name so that others can subscribe to it
          console.log('subscribe: ' + data.uuid);
          socket.join(data.uuid);
        } else {
          socket.emit('ready', {"api": "connect", "status": auth.status, "socketid": socket.id.toString(), "uuid": auth.uuid, "token": auth.token});
          // Have device join its uuid room name so that others can subscribe to it
          console.log('subscribe: ' + auth.uuid);
          socket.join(auth.uuid);
        }

      } else {
        socket.emit('notReady', {"api": "connect", "status": auth.status, "socketid": socket.id.toString(), "uuid": data.uuid});
      }
    });
  });

  socket.on('disconnect', function (data) {
    console.log('Presence offline for socket id: ' + socket.id.toString());
    require('./lib/updatePresence')(socket.id.toString());
    // Emit API request from device to room for subscribers
    require('./lib/getUuid')(socket.id.toString(), function(uuid){
      require('./lib/logEvent')(102, {"api": "disconnect", "socketid": socket.id.toString(), "uuid": uuid});
    });      

  });

  // Is this API still needed with MQTT?
  socket.on('subscribe', function(data, fn) { 
    require('./lib/authDevice')(data.uuid, data.token, function(auth){
      if (auth.authenticate == true){
        console.log('joining room ', data.uuid);
        socket.join(data.uuid); 

        // Emit API request from device to room for subscribers
        require('./lib/getUuid')(socket.id.toString(), function(uuid){
          var results = {"api": "subscribe", "socketid": socket.id.toString(), "uuid": uuid};
          console.log(results);
          try{
            fn(results);

            // // Emit API request from device to room for subscribers
            // socket.broadcast.to(data.uuid).emit('message', results);
            // if(uuid != data.uuid){
            //   socket.broadcast.to(uuid).emit('message', results);                
            // }


          } catch (e){
            console.log(e);
          }

        });      

      } else {
        console.log('subscribe failed for room ', data.uuid);

        var results = {"api": "subscribe", "result": false};
        // socket.broadcast.to(uuid).emit('message', results);

        console.log(results);
        try{
          fn(results);

          // // Emit API request from device to room for subscribers
          // socket.broadcast.to(data.uuid).emit('message', results);

        } catch (e){
          console.log(e);
        }

      }

    });
  });  

  // Is this API still needed with MQTT?
  socket.on('unsubscribe', function(data, fn) { 
      console.log('leaving room ', data.uuid);
      socket.leave(data.uuid); 
      // Emit API request from device to room for subscribers
      require('./lib/getUuid')(socket.id.toString(), function(uuid){
        var results = {"api": "unsubscribe", "socketid": socket.id.toString(), "uuid": uuid};
        // socket.broadcast.to(uuid).emit('message', results);

        try{
          fn(results);

          // // Emit API request from device to room for subscribers
          // socket.broadcast.to(data.uuid).emit('message', results);
          // if(uuid != data.uuid){
          //   socket.broadcast.to(uuid).emit('message', results);                
          // }

        } catch (e){
          console.log(e);
        }

      });      
  });  

  // APIs
  socket.on('status', function (fn) {

    // Emit API request from device to room for subscribers
    require('./lib/getUuid')(socket.id.toString(), function(uuid){
      // socket.broadcast.to(uuid).emit('message', {"api": "status"});

      require('./lib/getSystemStatus')(function(results){
        console.log(results);
        try{
          fn(results);
          
          // // Emit API request from device to room for subscribers
          // socket.broadcast.to(uuid).emit('message', results);

        } catch (e){
          console.log(e);
        }
      });

    });

  });

  socket.on('devices', function (data, fn) {
    if(data == undefined){
      var data = {};
    }
    // Emit API request from device to room for subscribers
    require('./lib/getUuid')(socket.id.toString(), function(uuid){
      var reqData = data;
      reqData["api"] = "devices";      
      // socket.broadcast.to(data.uuid).emit('message', reqData);
      // if(uuid != data.uuid){
      //   socket.broadcast.to(uuid).emit('message', reqData);                
      // }

      // Why is "api" still in the data object?
      delete reqData["api"];
      require('./lib/getDevices')(data, false, function(results){
        console.log(results);
        try{
          fn(results);

          // // Emit API request from device to room for subscribers
          // socket.broadcast.to(data.uuid).emit('message', results);
          // if(uuid != data.uuid){
          //   socket.broadcast.to(uuid).emit('message', results);                
          // }

        } catch (e){
          console.log(e);
        }
      });
    });
  });

  socket.on('whoami', function (data, fn) {
    if(data == undefined){
      var data = "";
    } else {
      data = data.uuid
    }
    // Emit API request from device to room for subscribers
    require('./lib/getUuid')(socket.id.toString(), function(uuid){
      var reqData = data;
      reqData["api"] = "whoami";      
      // socket.broadcast.to(data.uuid).emit('message', reqData);
      // if(uuid != data.uuid){
      //   socket.broadcast.to(uuid).emit('message', reqData);                
      // }

      delete reqData["api"];
      require('./lib/whoAmI')(data, false, function(results){
        console.log(results);
        try{
          fn(results);

          // // Emit API request from device to room for subscribers
          // socket.broadcast.to(data.uuid).emit('message', results);
          // if(uuid != data.uuid){
          //   socket.broadcast.to(uuid).emit('message', results);                
          // }

        } catch (e){
          console.log(e);
        }
      });
    });
  });

  socket.on('register', function (data, fn) {
    if(data == undefined){
      var data = {};
    }
    // Emit API request from device to room for subscribers
    require('./lib/getUuid')(socket.id.toString(), function(uuid){
      var reqData = data;
      reqData["api"] = "register";      
      // socket.broadcast.to(data.uuid).emit('message', reqData);
      // if(uuid != data.uuid){
      //   socket.broadcast.to(uuid).emit('message', reqData);                
      // }

      delete reqData["api"];
      require('./lib/register')(data, function(results){
        console.log(results);
        try{
          fn(results);

          // // Emit API request from device to room for subscribers
          // socket.broadcast.to(data.uuid).emit('message', results);
          // if(uuid != data.uuid){
          //   socket.broadcast.to(uuid).emit('message', results);                
          // }

        } catch (e){
          console.log(e);
        }
      });
    });
  });

  socket.on('update', function (data, fn) {
    if(data == undefined){
      var data = {};
    };
    // Emit API request from device to room for subscribers
    require('./lib/getUuid')(socket.id.toString(), function(uuid){
      var reqData = data;
      reqData["api"] = "update";      
      // socket.broadcast.to(data.uuid).emit('message', reqData);
      // if(uuid != data.uuid){
      //   socket.broadcast.to(uuid).emit('message', reqData);                
      // }

      delete reqData["api"];
      require('./lib/updateDevice')(data.uuid, data, function(results){
        console.log(results);
        try{
          fn(results);

          // // Emit API request from device to room for subscribers
          // socket.broadcast.to(data.uuid).emit('message', results);
          // if(uuid != data.uuid){
          //   socket.broadcast.to(uuid).emit('message', results);                
          // }

        } catch (e){
          console.log(e);
        }
      });
    });
  });

  socket.on('unregister', function (data, fn) {
    if(data == undefined){
      var data = {};
    }
    // Emit API request from device to room for subscribers
    require('./lib/getUuid')(socket.id.toString(), function(uuid){
      var reqData = data;
      reqData["api"] = "unregister";      
      // socket.broadcast.to(data.uuid).emit('message', reqData);
      // if(uuid != data.uuid){
      //   socket.broadcast.to(uuid).emit('message', reqData);                
      // }

      delete reqData["api"];
      require('./lib/unregister')(data.uuid, data, function(results){
        console.log(results);
        try{
          fn(results);

          // // Emit API request from device to room for subscribers
          // socket.broadcast.to(data.uuid).emit('message', results);
          // if(uuid != data.uuid){
          //   socket.broadcast.to(uuid).emit('message', results);                
          // }

        } catch (e){
          console.log(e);
        }
      });
    });
  });

  socket.on('events', function(data, fn) { 
    require('./lib/authDevice')(data.uuid, data.token, function(auth){

      // Emit API request from device to room for subscribers
      require('./lib/getUuid')(socket.id.toString(), function(uuid){

        var reqData = data;
        reqData["api"] = "events";      
        // socket.broadcast.to(data.uuid).emit('message', reqData);
        // if(uuid != data.uuid){
        //   socket.broadcast.to(uuid).emit('message', reqData);                
        // }


        if (auth.authenticate == true){

          require('./lib/getEvents')(data.uuid, function(results){
            console.log(results);

            try{
              fn(results);

              // // Emit API request from device to room for subscribers
              // socket.broadcast.to(data.uuid).emit('message', results);
              // if(uuid != data.uuid){
              //   socket.broadcast.to(uuid).emit('message', results);                
              // }

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

            // // Emit API request from device to room for subscribers
            // socket.broadcast.to(data.uuid).emit('message', results);
            // if(uuid != data.uuid){
            //   socket.broadcast.to(uuid).emit('message', results);                
            // }

          } catch (e){
            console.log(e);
          }

        }
  
      });

    });
  });  


  socket.on('authenticate', function(data, fn) { 
    require('./lib/authDevice')(data.uuid, data.token, function(auth){

      if (auth.authenticate == true){
        var results = {"uuid": data.uuid, "authentication": true};

        socket.emit('ready', {"api": "connect", "status": 201, "socketid": socket.id.toString(), "uuid": data.uuid});
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

    });
  });  

  socket.on('gatewayConfig', function(data, fn) { 
    console.log('gateway api req received');
    console.log(data);

    require('./lib/whoAmI')(data.uuid, true, function(check){
      console.log('whoami');
      console.log(check);
      if(check.type == 'gateway' && check.uuid == data.uuid && check.token == data.token){
        if(check.online == true){
          console.log("gateway online with socket id:", check.socketId);

          io.sockets.socket(check.socketId).emit("config", {devices: data.uuid, token: data.token, method: data.method, name: data.name, type: data.type, options: data.options}, function(results){
            console.log(results)

            // socket.emit('message', {"uuid": data.uuid, "online": true});
            // var results = {"uuid": data.uuid, "online": true};
            try{
              fn(results);
            } catch (e){
              console.log(e);
            }
            require('./lib/logEvent')(600, results);

          });

        } else {

          console.log("gateway offline");

          results = {
            "error": {
              "message": "Gateway offline",
              "code": 404
            }
          };

          try{
            fn(results);
          } catch (e){
            console.log(e);
          }
          require('./lib/logEvent')(600, results);


        }

      } else {

        gatewaydata = {
          "error": {
            "message": "Gateway not found",
            "code": 404
          }
        };
        try{
          fn(gatewaydata);
        } catch (e){
          console.log(e);
        }        
        require('./lib/logEvent')(600, gatewaydata);

      }
    });

  });  


  socket.on('message', function (messageX) {

    // socket.limiter.removeTokens(1, function(err, remainingRequests) {
    throttle.rateLimit(socket.id.toString(), function (err, limited) {
      var message = messageX;
      if (limited) {
        // response.writeHead(429, {'Content-Type': 'text/plain;charset=UTF-8'});
        // response.end('429 Too Many Requests - your IP is being rate limited');
        
        // TODO: Emit rate limit exceeded message 
        console.log("Rate limit exceeded for socket:", socket.id.toString());
        console.log("message", message);

      } else {
        console.log("Sending message for socket:", socket.id.toString());
        console.log("message", message);

        if(message == undefined){
          var message = {};
          return;
        } else if (typeof message !== 'object'){
          try{
            message = JSON.parse(message);
          } catch(e){
            console.log('ERROR', e);
            return;
          }
          
        }
        console.log("message", message);

        var eventData = message;

        // Broadcast to room for pubsub
        require('./lib/getUuid')(socket.id.toString(), function(uuid){
          eventData["api"] = "message";
          eventData["fromUuid"] = uuid;
          // socket.broadcast.to(uuid).emit('message', eventData)  

          var dataMessage = message.message;
          // var dataMessage = message;
          if (dataMessage){
            dataMessage["fromUuid"] = uuid;
          }           

          console.log('devices: ' + message.devices);
          console.log('message: ' + JSON.stringify(dataMessage));
          console.log('protocol: ' + message.protocol);

          if(message.devices == "all" || message.devices == "*"){

            // socket.broadcast.emit('message', 'broadcast', JSON.stringify(dataMessage));
            socket.broadcast.emit('message', 'broadcast', dataMessage);

            if(message.protocol == undefined && message.protocol != "mqtt"){
              mqttclient.publish('broadcast', JSON.stringify(dataMessage), {qos:qos});
              // mqttclient.publish('broadcast', dataMessage, {qos:qos});
            }

            require('./lib/logEvent')(300, eventData);

          } else {

            var devices = message.devices;

            if( typeof devices === 'string' ) {
                devices = [ devices ];
            };

            if(devices){

              devices.forEach( function(device) { 

                if (device.length == 36){

                  // Send SMS if UUID has a phoneNumber
                  require('./lib/whoAmI')(device, false, function(check){
                    if(check.phoneNumber){
                      console.log("Sending SMS to", check.phoneNumber)
                      require('./lib/sendSms')(device, JSON.stringify(message.message), function(check){
                        console.log('Sent SMS!');
                      });
                    } else if(check.type && check.type == 'gateway'){
                      // Any special gateway messaging needed?
                    }
                  });

                  // Broadcast to room for pubsub
                  console.log('sending message to room: ' + device);            
                  console.log('message', dataMessage);
                  // socket.broadcast.to(device).emit('message', device, JSON.stringify(dataMessage));
                  socket.broadcast.to(device).emit('message', device, dataMessage);

                  if(message.protocol == undefined && message.protocol != "mqtt"){
                    mqttclient.publish(device, JSON.stringify(dataMessage), {qos:qos});
                    // mqttclient.publish(device, dataMessage, {qos:qos});
                  }
                }

              });


            }

            require('./lib/logEvent')(300, eventData);
          }

        });


      }
    });

  });

});

// Handle MQTT Messages
try{
  mqttclient.subscribe('*');
  // mqttclient.publish('742401f1-87a4-11e3-834d-670dadc0ddbf', 'Hello mqtt');

  mqttclient.on('message', function (topic, message) {
    // console.log('mqtt message received', topic, message);
    console.log('mqtt message received');
    console.log(topic);
    console.log(message);

    if (topic.length == 36){            

      // Send SMS if UUID has a phoneNumber
      require('./lib/whoAmI')(topic, false, function(smscheck){
        if(smscheck.phoneNumber){
          console.log("Sending SMS to", smscheck.phoneNumber)
          require('./lib/sendSms')(topic, message, function(smscheck){
            console.log('Sent SMS!');
          });
        }
      });

      // Broadcast to room for pubsub
      console.log('sending message to room: ' + topic);            
      io.sockets.in(topic).emit('message', topic, message);

      var eventData = {devices: topic, message: message}
      require('./lib/logEvent')(300, eventData);

    }

  });  
} catch(e){
  console.log('no mqtt server found');
}


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
server.get('/devices', function(req, res){

  res.setHeader('Access-Control-Allow-Origin','*');
  require('./lib/getDevices')(req.query, false, function(data){
    // console.log(data);
    // io.sockets.in(req.params.uuid).emit('message', data)
    if(data.error){
      res.json(data.error.code, data);
    } else {
      res.json(data);
    }

  });
});


// curl http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
server.get('/devices/:uuid', function(req, res){
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
  require('./lib/updateDevice')(req.params.uuid, req.params, function(data){
    console.log(data);
    // io.sockets.in(req.params.uuid).emit('message', data)
    if(data.error){
      res.json(data.error.code, data);
    } else {
      res.json(data);
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
  require('./lib/authDevice')(req.params.uuid, req.query.token, function(auth){
    if (auth.authenticate == true){  
      req.query.owner = req.params.uuid;
      delete req.query.token;
      require('./lib/getDevices')(req.query, true, function(data){
        console.log(data);
        // io.sockets.in(req.params.uuid).emit('message', data)
        if(data.error){
          res.json(data.error.code, data);
        } else {
          res.json(data);
        }
      });
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


// curl -X GET http://localhost:3000/events/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc?token=qirqglm6yb1vpldixflopnux4phtcsor
server.get('/events/:uuid', function(req, res){
  res.setHeader('Access-Control-Allow-Origin','*');
  require('./lib/authDevice')(req.params.uuid, req.query.token, function(auth){
    if (auth.authenticate == true){  
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

// curl -X GET http://localhost:3000/events/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc?token=qirqglm6yb1vpldixflopnux4phtcsor
server.get('/subscribe/:uuid', function(req, res){
  res.setHeader('Access-Control-Allow-Origin','*');
  require('./lib/authDevice')(req.params.uuid, req.query.token, function(auth){
    if (auth.authenticate == true){  

      var foo = JSONStream.stringify();
      foo.on("data", function(data){
        console.log(data);
        data = data + '\n';
      })
      require('./lib/subscribe')(req.params.uuid)
        .pipe(foo)
        .pipe(res);

      // // TODO: Add /n to stream to server current record
      // require('./lib/subscribe')(req.params.uuid)
      //   .pipe(JSONStream.stringify())
      //   .pipe(res);

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

// curl -X GET http://localhost:3000/authenticate/81246e80-29fd-11e3-9468-e5f892df566b?token=5ypy4rurayktke29ypbi30kcw5ovfgvi
server.get('/authenticate/:uuid', function(req, res){
  res.setHeader('Access-Control-Allow-Origin','*');
  require('./lib/authDevice')(req.params.uuid, req.query.token, function(auth){
    if (auth.authenticate == true){  
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


// curl -X POST -d '{"devices": "all", "message": {"yellow":"off"}}' http://localhost:3000/messages
// curl -X POST -d '{"devices": ["ad698900-2546-11e3-87fb-c560cb0ca47b","2f3113d0-2796-11e3-95ef-e3081976e170"], "message": {"yellow":"off"}}' http://localhost:3000/messages
// curl -X POST -d '{"devices": "ad698900-2546-11e3-87fb-c560cb0ca47b", "message": {"yellow":"off"}}' http://localhost:3000/messages
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
  var message = body.message;
  var eventData = {devices: devices, message: message}

  console.log('devices: ' + devices);
  console.log('message: ' + JSON.stringify(message));

  if(devices == "all" || devices == "*"){

      mqttclient.publish('broadcast', JSON.stringify(message), {qos:qos});
      io.sockets.emit('message', 'broadcast', message);

      require('./lib/logEvent')(300, eventData);
      if(eventData.error){
        res.json(eventData.error.code, eventData);
      } else {
        res.json(eventData);
      }

  } else {

    if( typeof devices === 'string' ) {
        devices = [ devices ];
    };

    devices.forEach( function(device) { 

      if (device.length == 36){
            
        // Send SMS if UUID has a phoneNumber
        require('./lib/whoAmI')(device, false, function(smscheck){
          if(smscheck.phoneNumber){
            console.log("Sending SMS to", smscheck.phoneNumber)
            require('./lib/sendSms')(device, JSON.stringify(message), function(smscheck){
              console.log('Sent SMS!');
            });
          }
        });

        // Broadcast to room for pubsub
        console.log('sending message to room: ' + device);

        mqttclient.publish(device, JSON.stringify(message), {qos:qos});
        io.sockets.in(device).emit('message', device, message);

      }
      
    });

    require('./lib/logEvent')(300, eventData);
    if(eventData.error){
      res.json(eventData.error.code, eventData);
    } else {
      res.json(eventData);
    }

  }

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
    io.sockets.in(uuid).emit('message', uuid, message)

    var eventData = {devices: uuid, message: message}
    require('./lib/logEvent')(301, eventData);
    if(eventData.error){
      res.json(eventData.error.code, eventData);
    } else {
      res.json(eventData);
    }

  });
});


// Serve static website
var file = new nstatic.Server('');
server.get('/demo/:uuid/:token', function(req, res, next) {
  file.serveFile('/demo.html', 200, {}, req, res);
});

server.get('/', function(req, res, next) {
    file.serveFile('/index.html', 200, {}, req, res);
});

server.get(/^\/.*/, function(req, res, next) {
    file.serve(req, res, next);
});


server.listen(process.env.PORT || config.port, function() {
  console.log("\n SSSSS  kk                            tt    ");
  console.log("SS      kk  kk yy   yy nn nnn    eee  tt    ");
  console.log(" SSSSS  kkkkk  yy   yy nnn  nn ee   e tttt  ");
  console.log("     SS kk kk   yyyyyy nn   nn eeeee  tt    ");
  console.log(" SSSSS  kk  kk      yy nn   nn  eeeee  tttt ");
  console.log("                yyyyy                         ");
  console.log('\nSkynet %s environment loaded... ', app.environment);
  console.log('Skynet listening at %s', server.url);  
});
