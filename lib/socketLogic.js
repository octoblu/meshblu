var whoAmI = require('./whoAmI');
var config = require('../config');
var getData = require('./getData');
var logData = require('./logData');
var logEvent = require('./logEvent');
var register = require('./register');
var getEvents = require('./getEvents');
var getDevices = require('./getDevices');
var authDevice = require('./authDevice');
var unregister = require('./unregister');
var claimDevice = require('./claimDevice');
var securityImpl = require('./getSecurityImpl');
var updateSocketId = require('./updateSocketId');
var updatePresence = require('./updatePresence');
var getLocalDevices = require('./getLocalDevices');
var getSystemStatus = require('./getSystemStatus');
var updateFromClient = require('./updateFromClient');


function getDevice(socket, callback) {
  console.log('getDevice socket info:', socket.id, socket.skynetDevice);

  if(socket.skynetDevice){
    return callback(null, socket.skynetDevice);
  }else{
    return callback(new Error('skynetDevice not found for socket' + socket), null);
  }

}


function socketLogic (socket, secure, skynet){
  console.log('\nsocket connected...');
  //TODO check x-forward handshake header on load balancer?
  var ipAddress = socket.request.connection.remoteAddress;
  socket.ipAddress = ipAddress;
  //socket.handshake.address.address; <-busted as of 1.0.6
  console.log('\nipAddress', ipAddress);

  console.log('Websocket connection detected. Requesting identification from socket id: ', socket.id);
  logEvent(100, {"socketid": socket.id, "protocol": "websocket"});

  socket.emit('identify', { socketid: socket.id });
  socket.on('identity', function (data) {
    console.log('identity received', data);
    data.socketid = socket.id;
    data.ipAddress = ipAddress;
    data.secure = secure;
    if(!data.protocol){
      data.protocol = "websocket";
    }
    console.log('Identity received: ', JSON.stringify(data));
    // logEvent(101, data);
    updateSocketId(data, function(auth){
      if(config.broadcastActivity){
        skynet.sendActivity({ipAddress: socket.ipAddress}, function(result){
        });
      }

      if (auth.status == 201){

          socket.skynetDevice = auth.device;

          socket.emit('ready', {"api": "connect", "status": auth.status, "socketid": socket.id, "uuid": auth.device.uuid, "token": auth.device.token});
          // Have device join its uuid room name so that others can subscribe to it
          console.log('subscribe: ' + auth.device.uuid);

          //Announce presence online
          var message = {};
          message.payload = {"online":true};
          message.devices = "*";
          skynet.sendMessage(auth.device, message);

          //make sure not in there already:
          try{
            socket.leave(auth.device.uuid);
          }catch(lexp){
            console.log('error leaving room', lexp);
          }
          socket.join(auth.device.uuid);

      } else {
        socket.emit('notReady', {"api": "connect", "status": auth.status, "uuid": data.uuid});
      }

      whoAmI(data.uuid, false, function(results){
        data.auth = auth;
        // results._id.toString();
        // delete results._id;
        data.fromUuid = results;
        logEvent(101, data);
      });

    });
  });

  socket.on('disconnect', function (data) {
    skynet.sendActivity({}, socket);

    console.log('Presence offline for socket id: ', socket.id);
    updatePresence(socket.id);
    // Emit API request from device to room for subscribers
    getDevice(socket, function(err, device){

      //Announce presence offline
      var message = {};
      message.payload = {"online":false};
      message.devices = "*";
      skynet.sendMessage(device, message);

      device = device || null;
      logEvent(102, {api: "disconnect", socketid: socket.id, device: device});
    });

  });



socket.on('subscribeText', function(data, fn) {
    skynet.sendActivity({}, socket);

    if(!data){ return; }

    getDevice(socket, function(err, device){
      if(err){ return; }

      if(data.uuid && data.uuid.length > 30){
        //no token provided, attempt to only listen for public broadcasts FROM this uuid
        whoAmI(data.uuid, false, function(results){
          if(results.error){
            fn(results);
          }else{
            if(securityImpl.canRead(device, results)){
              socket.join(data.uuid + "_tb");
              fn({"api": "subscribe", "socketid": socket.id, "toUuid": data.uuid, "result": true});
            }else{
              fn({error: "unauthorized access"});
            }

          }

          data.toUuid = results;
          logEvent(204, data);

        });

      }
    });


  });

  // Is this API still needed with MQTT?
  socket.on('subscribe', function(data, fn) {
    skynet.sendActivity({}, socket);

    if(!data){ return; }

    getDevice(socket, function(err, device){
      if(err){ return; }

      if(data.uuid && data.uuid.length > 30 && !data.token){
        //no token provided, attempt to only listen for public broadcasts FROM this uuid
        whoAmI(data.uuid, false, function(results){
          if(results.error){
            fn(results);
          }else{
            if(securityImpl.canRead(device, results)){
              socket.join(data.uuid + "_bc");
              if(fn){
                fn({"api": "subscribe", "socketid": socket.id, "toUuid": data.uuid, "result": true});
              }
            }else{
              if(fn){
                fn({error: "unauthorized access"});
              }
            }

          }

          data.toUuid = results;
          logEvent(204, data);

        });

      }else{
        //token provided, attempt to listen to any broadcast FOR this uuid
        authDevice(data.uuid, data.token, function(auth){
          if (auth.authenticate){
            console.log('joining rooms ', data.uuid);
            socket.join(data.uuid);
            socket.join(data.uuid + "_bc"); //shouldnt be here?

            // Emit API request from device to room for subscribers
            var results = {"api": "subscribe", "socketid": socket.id, "fromUuid": device.uuid, "toUuid": data.uuid, "result": true};

            data.auth = auth;
            data.fromUuid = device;
            data.toUuid = auth.device;
            logEvent(204, data);

            try{
              fn(results);
            } catch (e){
              console.log(e);
            }

          } else {
            console.log('subscribe failed for room ', data.uuid);

            var results = {"api": "subscribe", "uuid": data.uuid, "result": false};
            // socket.broadcast.to(uuid).emit('message', results);

            logEvent(204, results);

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


  });

  // Is this API still needed with MQTT?
  socket.on('unsubscribe', function(data, fn) {
    skynet.sendActivity({}, socket);

    console.log('leaving room ', data.uuid);
    socket.leave(data.uuid);
    socket.leave(data.uuid + "_bc");
    // Emit API request from device to room for subscribers
    getDevice(socket, function(err, device){
      if(err){ return; }
      var results = {"api": "unsubscribe", "socketid": socket.id, "uuid": device.uuid};
      // socket.broadcast.to(uuid).emit('message', results);

      whoAmI(data.uuid, false, function(toCheck){
        data.fromUuid = device;
        data.toUuid = toCheck;
        logEvent(205, data);
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
    skynet.sendActivity({}, socket);

    skynet.throttles.query.rateLimit(socket.id, function (err, limited) {
      if(limited){
        console.log('status throttled', socket.id);
      }else{

        // Emit API request from device to room for subscribers
        getDevice(socket, function(err, device){
          if(err){ return; }
          // socket.broadcast.to(uuid).emit('message', {"api": "status"});

          getSystemStatus(function(results){

            results.fromUuid = device;
            logEvent(200, results);
            console.log(results);

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
    skynet.sendActivity({}, socket);

    skynet.throttles.query.rateLimit(socket.id, function (err, limited) {
      if(limited){
        console.log('query throttled', socket.id);
      }else{

        if(!data || (typeof data != 'object')){
          data = {};
        }

        getDevice(socket, function(err, device){
          if(err){ return; }
          var reqData = data;
          getDevices(device, data, false, function(results){
            results.fromUuid = device;
            logEvent(403, results);
            console.log(results);

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

  socket.on('mydevices', function (data, fn) {
    skynet.sendActivity({}, socket);

    skynet.throttles.query.rateLimit(socket.id, function (err, limited) {
      if(limited){
        console.log('query throttled', socket.id);
      }else{
        getDevice(socket, function(err, device){
          if(err){ return; }
          getDevices(device, {owner: device.uuid}, true, function(results){
            try{
              results.fromUuid = device.uuid;
              logEvent(403, results);
              console.log(results);
              fn(results);

            } catch (e){
              console.log(e);
            }
          });
        });
      }
    });
  });


  socket.on('localdevices', function (data, fn) {
    skynet.sendActivity({}, socket);

    skynet.throttles.query.rateLimit(socket.id, function (err, limited) {
      if(limited){
        console.log('query throttled', socket.id);
      }else{

        if(!data || (typeof data != 'object')){
          data = {};
        }
        // Emit API request from device to room for subscribers
        getDevice(socket, function(err, device){
          if(err){ return; }
          getLocalDevices(device, false, function(results){
            results.fromUuid = device;
            logEvent(403, results);
            console.log(results);

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


  socket.on('claimdevice', function (data, fn) {
    skynet.sendActivity({}, socket);

    skynet.throttles.query.rateLimit(socket.id, function (err, limited) {
      if(limited){
        console.log('query throttled', socket.id);
      }else{

        if(!data || (typeof data != 'object')){
          data = {};
        }
        // Emit API request from device to room for subscribers
        getDevice(socket, function(err, device){
          if(err){ return; }
          claimDevice(device, data, function(err, results){
            logEvent(403, {error: err, results: results, fromUuid: device});
            console.log('claimdevice', err, results);

            try{
              fn({error: err, results: results});

            } catch (e){
              console.log(e);
            }
          });
        });
      }
    });
  });

  socket.on('whoami', function (data, fn) {
    skynet.sendActivity({}, socket);

    skynet.throttles.whoami.rateLimit(socket.id, function (err, limited) {
      if(limited){
        console.log('whoami throttled', socket.id);
      }else{
        getDevice(socket, function(err, device){
          if(err){ return; }
          try{
            fn(device);
          } catch (e){
            console.log(e);
          }
        });

      }
    });

  });


  socket.on('register', function (data, fn) {
    skynet.sendActivity({}, socket);

    if(!data){
      data = {};
    }
    data.socketid = socket.id;
    data.ipAddress = ipAddress;

    register(data, function(results){

      whoAmI(data.uuid, false, function(check){

        results.fromUuid = check;

        if(!check.error){
          socket.skynetDevice = check;
        }

        logEvent(400, results);
      });



      try{
        fn(results);

      } catch (e){
        console.log(e);
      }
    });

  });

  socket.on('update', function (data, fn) {
    skynet.sendActivity({}, socket);

    if(!data){
      data = {};
    }
    // Emit API request from device to room for subscribers
    getDevice(socket, function(err, fromDevice){
      if(err){ return; }

      updateFromClient(fromDevice, data, fn);

    });
  });

  socket.on('unregister', function (data, fn) {
    skynet.sendActivity({}, socket);

    if(!data){
      data = {};
    }
    // Emit API request from device to room for subscribers
    getDevice(socket, function(err, device){
      if(err){ return; }
      var reqData = data;
      unregister(device, data.uuid, function(results){

        console.log(results);

        if(results == null || results == undefined){
          results = {};
        }
        results.fromUuid = device;
        logEvent(402, results);

        try{
          fn(results);

        } catch (e){
          console.log(e);
        }
      });
    });
  });

  socket.on('events', function(data, fn) {
    skynet.sendActivity({}, socket);

    authDevice(data.uuid, data.token, function(auth){

      // Emit API request from device to room for subscribers
      getDevice(socket, function(err, device){
        if(err){ return; }
        var reqData = data;
        reqData.api = "events";

        if (auth.authenticate){

          getEvents(data.uuid, function(results){
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
    skynet.sendActivity({}, socket);

    authDevice(data.uuid, data.token, function(auth){
      var results;
      if (auth.authenticate){
        results = {"uuid": data.uuid, "authentication": true};

        socket.emit('ready', {"api": "connect", "status": 201, "socketid": socket.id, "uuid": data.uuid});
        console.log('subscribe: ' + data.uuid);
        socket.join(data.uuid);

        try{
          fn(results);
        } catch (e){
          console.log(e);
        }

      } else {
        results = {"uuid": data.uuid, "authentication": false};
        try{
          fn(results);
        } catch (e){
          console.log(e);
        }

      }

      // require('./lib/whoAmI')(data.uuid, false, function(check){
      whoAmI(data.uuid, false, function(check){
        // check._id.toString();
        // delete check._id;
        results.toUuid = check;
        logEvent(102, results);
      });


    });
  });

  socket.on('data', function (messageX, fn) {
    skynet.sendActivity({}, socket);

    skynet.throttles.data.rateLimit(socket.id, function (err, limited) {
      if(limited){
        console.log('data throttled', socket.id);
      }else{
        var data = messageX;

        getDevice(socket, function(err, fromDevice){
          if(err){ return; }

          delete data.token;

          logData(data, function(results){
            console.log(results);

            // Send messsage regarding data update
            var message = {};
            message.payload = data;
            // message.devices = data.uuid;
            message.devices = "*";

            console.log('message: ' + JSON.stringify(message));

            skynet.sendMessage(fromDevice, message);


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

  socket.on('getdata', function (data, fn) {
    skynet.sendActivity({}, socket);

    skynet.throttles.query.rateLimit(socket.id, function (err, limited) {
      if(limited){
        console.log('query throttled', socket.id);
      }else{

        authDevice(data.uuid, data.token, function(auth){

          if (auth.authenticate){

            if(!data || (typeof data != 'object')){
              data = {};
            }
            data.params = {};
            data.query = {};

            data.params.uuid = data.uuid;
            data.query.start = data.start; // time to start from
            data.query.finish = data.finish; // time to end
            data.query.limit = data.limit; // 0 bypasses the limit

            getData(data, function(results){
              // if(err){ return; }

              results.fromUuid = socket.skynetDevice.uuid;
              console.log(results);

              try{
                fn(results);

              } catch (e){
                console.log(e);
              }

            });

          } else {
            console.log('UUID not found or invalid token ', data.uuid);

            var results = {"api": "getdata", "result": false};

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
  });


  socket.on('gatewayConfig', function(data) {
    skynet.sendActivity({}, socket);

    getDevice(socket, function(err, device){
      if(err){ return; }
      skynet.gateway.config(device, data);
    });

  });

  socket.on('gatewayConfigAck', function (data) {
    skynet.sendActivity({}, socket);

    getDevice(socket, function(err, device){
      if(err){ return; }
      skynet.gateway.configAck(device, data);
    });
  });

  socket.on('messageAck', function (data) {
    skynet.sendActivity({}, socket);

    getDevice(socket, function(err, fromDevice){
      if(fromDevice){
        whoAmI(data.devices, false, function(check){
          data.fromUuid = fromDevice.uuid;
          if(!check.error && securityImpl.canSend(fromDevice, check)){
            skynet.emitToClient('messageAck', check, data);
          }
        });
      }
    });
  });





  socket.on('tb', function (messageX) {
    skynet.sendActivity({}, socket);

    // socket.limiter.removeTokens(1, function(err, remainingRequests) {
    skynet.throttles.message.rateLimit(socket.id, function (err, limited) {
      var message = messageX;

      if (limited) {

        // TODO: Emit rate limit exceeded message
        console.log("Rate limit exceeded for socket:", socket.id);
        console.log("message", message);

      } else {
        console.log("Sending message for socket:", socket.id, message);

        if(!message){
          return;
        }else{
          message = message.toString();

          // Broadcast to room for pubsub
          getDevice(socket, function(err, fromDevice){
            if(fromDevice){
              skynet.sendMessage(fromDevice, {payload: message}, 'tb');
            }
          });
        }

      }
    });

  });



  socket.on('message', function (messageX) {
    skynet.sendActivity({}, socket);

    // socket.limiter.removeTokens(1, function(err, remainingRequests) {
    skynet.throttles.message.rateLimit(socket.id, function (err, limited) {
      var message = messageX;

      if (limited) {

        // TODO: Emit rate limit exceeded message
        console.log("Rate limit exceeded for socket:", socket.id);
        console.log("message", message);

      } else {
        console.log("Sending message for socket:", socket.id, message);

        if(typeof message !== 'object'){
          return;
        }else{
          // Broadcast to room for pubsub
          getDevice(socket, function(err, fromDevice){
            if(fromDevice){
              message.api = "message";
              skynet.sendMessage(fromDevice, message);
            }
          });
        }

      }
    });

  });

  socket.on('directText', function (messageX) {
    skynet.sendActivity({}, socket);

    // socket.limiter.removeTokens(1, function(err, remainingRequests) {
    skynet.throttles.message.rateLimit(socket.id, function (err, limited) {
      var message = messageX;

      if (limited) {

        // TODO: Emit rate limit exceeded message
        console.log("Rate limit exceeded for socket:", socket.id);
        console.log("message", message);

      } else {
        console.log("Sending message for socket:", socket.id, message);

        getDevice(socket, function(err, fromDevice){
          if(fromDevice){
            skynet.sendMessage(fromDevice, message, 'tb');
          }
        });

      }
    });

  });

}


module.exports = socketLogic;
