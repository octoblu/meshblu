var nstatic = require('node-static');

module.exports = {
  setup: function (server) {
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
    
          var foo = JSONStream.stringify(open='\n', sep=',\n', close='\n\n');
          foo.on("data", function(data){
            console.log(data);
            data = data + '\r\n';
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
    
      require('./lib/authDevice')(req.params.uuid, req.params.token, function(auth){
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
      require('./lib/authDevice')(req.params.uuid, req.query.token, function(auth){
        if (auth.authenticate == true){
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
};
