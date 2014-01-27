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
// var tropo_webapi = require('tropo-webapi');


var mqtt = require('mqtt'),
  qos = 0;
var mqttsettings = {
  keepalive: 1000, // seconds
  protocolId: 'MQIsdp',
  protocolVersion: 3,
  clientId: 'skynet'
}

// create mqtt connection
try {
  var mqttclient = mqtt.createClient(1883, 'mqtt.skynet.im', mqttsettings);
  // var mqttclient = mqtt.createClient(1883, 'localhost', mqttsettings);
} catch(err){
  console.log('No MQTT server found.');
}

var server = restify.createServer();
var io = socketio.listen(server);

server.use(restify.acceptParser(server.acceptable));
server.use(restify.queryParser());
server.use(restify.bodyParser());

process.on("uncaughtException", function(error) {
  return console.log(error.stack);
});

io.sockets.on('connection', function (socket) {

  console.log('Websocket connection detected. Requesting identification from socket id: ' + socket.id.toString());
  require('./lib/logEvent')(100, {"socketId": socket.id.toString(), "protocol": "websocket"});
  
  socket.emit('identify', { socketid: socket.id.toString() });
  socket.on('identity', function (data) {
    data["socketid"] = socket.id.toString();
    console.log('Identity received: ' + JSON.stringify(data));
    require('./lib/logEvent')(101, data);
    require('./lib/updateSocketId')(data, function(auth){
      if (auth.status == 201){
        socket.emit('ready', {"api": "connect", "status": auth.status, "socketid": socket.id.toString(), "uuid": data.uuid});
        console.log('subscribe: ' + data.uuid);
        // if(config.mqtt){
          // mqttclient.publish(data.uuid, '{"api": "connect", "status": 201, "socketid": ' + socket.id.toString() + ', "uuid": ' + data.uuid + '}, {qos:' + qos + '}');
        // } else {
          // Have device join its uuid room name so that others can subscribe to it
          socket.join(data.uuid);
          // socket.broadcast.to(data.uuid).emit('message', {"api": "connect", "status": auth.status, "socketid": socket.id.toString(), "uuid": data.uuid});          
        // }
      } else {
        socket.emit('notReady', {"api": "connect", "status": auth.status, "socketid": socket.id.toString(), "uuid": data.uuid});
        // if(config.mqtt){
        //   mqttclient.publish(data.uuid, '{"api": "connect", "status": ' + auth.status + ', "socketid": ' + socket.id.toString() + ', "uuid": ' + data.uuid + '}, {qos:' + qos + '}');
        // } else {
        //   socket.broadcast.to(data.uuid).emit('message', {"api": "connect", "status": auth.status, "uuid": data.uuid});
        // }
      }
    });
  });

  socket.on('disconnect', function (data) {
    console.log('Presence offline for socket id: ' + socket.id.toString());
    require('./lib/updatePresence')(socket.id.toString());
    // Emit API request from device to room for subscribers
    require('./lib/getUuid')(socket.id.toString(), function(uuid){
      require('./lib/logEvent')(102, {"api": "disconnect", "socketid": socket.id.toString(), "uuid": uuid});
      // if(config.mqtt){
      //   mqttclient.publish(uuid, '{"api": "disconnect", "socketid": ' + socket.id.toString() + ', "uuid": ' + uuid + '}, {qos:' + qos + '}');
      // } else {
      //   socket.broadcast.to(uuid).emit('message', {"api": "disconnect", "socketid": socket.id.toString(), "uuid": uuid});
      // }
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



  socket.on('message', function (data) {
    if(data == undefined){
      var data = {};
    } else if (typeof data !== 'object'){
      data = JSON.parse(data);
    }

    var eventData = data

    // Broadcast to room for pubsub
    require('./lib/getUuid')(socket.id.toString(), function(uuid){
      eventData["api"] = "message";
      eventData["fromUuid"] = uuid;
      // socket.broadcast.to(uuid).emit('message', eventData)  

      var dataMessage = data.message;
      dataMessage["fromUuid"] = uuid;

      console.log('devices: ' + data.devices);
      console.log('message: ' + JSON.stringify(dataMessage));
      console.log('protocol: ' + data.protocol);

      if(data.devices == "all" || data.devices == "*"){

        // if(data.qos == undefined){
          socket.broadcast.emit('message', 'broadcast', JSON.stringify(dataMessage));
        // }
        if(data.protocol == undefined && data.protocol != "mqtt"){
          mqttclient.publish('broadcast', JSON.stringify(dataMessage), {qos:qos});
        }


        require('./lib/logEvent')(300, eventData);

      } else {

        var devices = data.devices;

        if( typeof devices === 'string' ) {
            devices = [ devices ];
        };

        devices.forEach( function(device) { 

          // if(data.qos == undefined){
            // Broadcast to room for pubsub
            console.log('sending message to room: ' + device);            
            socket.broadcast.to(device).emit('message', device, JSON.stringify(dataMessage));
          // }
          if(data.protocol == undefined && data.protocol != "mqtt"){
            mqttclient.publish(device, JSON.stringify(dataMessage), {qos:qos});
          }


        });

        require('./lib/logEvent')(300, eventData);
      }

    });

  });

});

// curl http://localhost:3000/status
server.get('/status', function(req, res){
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


// curl http://localhost:3000/devices
// curl http://localhost:3000/devices?key=123
// curl http://localhost:3000/devices?online=true
server.get('/devices', function(req, res){

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


// curl -X POST -d "name=arduino&description=this+is+a+test" http://localhost:3000/devices
server.post('/devices', function(req, res){
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

      // if(config.mqtt){
        mqttclient.publish('broadcast', JSON.stringify(message), {qos:qos});
      // } else {    
        io.sockets.emit('message', 'broadcast', message);
      // }
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
      // Broadcast to room for pubsub
      console.log('sending message to room: ' + device);

      // if(config.mqtt){
        mqttclient.publish(device, JSON.stringify(message), {qos:qos});
      // } else {
        io.sockets.in(device).emit('message', device, message)
      // }
      
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

  console.log(req.params);
  var data = JSON.parse(json);
  var phone = req.params.phoneNumber;
  var message = "";

  require('./lib/getPhone')(phone, function(uuid){
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
