var whoAmI = require('./whoAmI');
var config = require('../config');
var getData = require('./getData');
var logData = require('./logData');
var logEvent = require('./logEvent');
var register = require('./register');
var getEvents = require('./getEvents');
var getDevice = require('./getDevice');
var getDevices = require('./getDevices');
var authDevice = require('./authDevice');
var bindSocket = require('./bindSocket');
var unregister = require('./unregister');
var claimDevice = require('./claimDevice');
var securityImpl = require('./getSecurityImpl');
var updateSocketId = require('./updateSocketId');
var updatePresence = require('./updatePresence');
var getLocalDevices = require('./getLocalDevices');
var getSystemStatus = require('./getSystemStatus');

function socketLogic (socket, secure, skynet){
  console.log('socket connected...');
  var ipAddress = socket.handshake.address.address;

  // socket.limiter = new RateLimiter(1, "second", true);

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
      if (auth.status == 201){

          socket.skynetDevice = auth.device;

          socket.emit('ready', {"api": "connect", "status": auth.status, "socketid": socket.id, "uuid": auth.device.uuid, "token": auth.device.token});
          // Have device join its uuid room name so that others can subscribe to it
          console.log('subscribe: ' + auth.device.uuid);
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
    console.log('Presence offline for socket id: ', socket.id);
    updatePresence(socket.id);
    // Emit API request from device to room for subscribers
    getDevice(socket, function(err, device){
      device = device || null;
      logEvent(102, {api: "disconnect", socketid: socket.id, device: device});
    });

  });

  // Is this API still needed with MQTT?
  socket.on('subscribe', function(data, fn) {
    if(data.uuid && data.uuid.length > 30 && !data.token){
      //no token provided, attempt to only listen for public broadcasts FROM this uuid
      whoAmI(data.uuid, false, function(results){
        if(results.error){
          fn(results);
        }else{
          socket.join(data.uuid + "_bc");
          fn({"api": "subscribe", "socketid": socket.id, "toUuid": data.uuid, "result": true});
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
          socket.join(data.uuid + "_bc");

          // Emit API request from device to room for subscribers
          getDevice(socket, function(err, device){
            if(err){ return; }
            var results = {"api": "subscribe", "socketid": socket.id, "fromUuid": device.uuid, "toUuid": data.uuid, "result": true};

            whoAmI(data.uuid, false, function(toCheck){
              data.auth = auth;
              data.fromUuid = device;
              data.toUuid = toCheck;
              logEvent(204, data);
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

  // Is this API still needed with MQTT?
  socket.on('unsubscribe', function(data, fn) {
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

    skynet.throttles.whoami.rateLimit(socket.id, function (err, limited) {
      if(limited){
        console.log('whoami throttled', socket.id);
      }else{

        if(!data){
          data = "";
        } else {
          data = data.uuid;
        }
        // Emit API request from device to room for subscribers
        getDevice(socket, function(err, device){
          if(err){ return; }
          var reqData = data;
          whoAmI(data, false, function(results){
            results.fromUuid = device;
            logEvent(500, results);

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

    if(config.redis){

      getDevice(socket, function(err, device){
        if(err){ return fn({error: 'invalid client'}); }

        whoAmI(data.uuid, false, function(check){
          if(!check.error){
            target = check;
            if(target.socketid && securityImpl.canSend(device, target)){
              if(target.secure && config.tls){
                skynet.ios.sockets.socket(target.socketid).emit("bindSocket", {fromUuid: device.uuid}, bindReply);
              } else {
                skynet.io.sockets.socket(target.socketid).emit("bindSocket", {fromUuid: device.uuid}, bindReply);
              }
            }else{
              console.log('client target',device.uuid, target);
              return fn({error: 'invalid client or target'});
            }
          }
        });

      });

    } else {
      // Redis not defined in config.js
      return fn({error: 'bind not supported without redis'});
    }
  });

  socket.on('register', function (data, fn) {
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
    if(!data){
      data = {};
    }
    // Emit API request from device to room for subscribers
    getDevice(socket, function(err, fromDevice){
      if(err){ return; }

      skynet.handleUpdate(fromDevice, data, fn);

    });
  });

  socket.on('unregister', function (data, fn) {
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


  socket.on('gatewayConfig', function(data, fn) {
    skynet.gatewayConfig(data, fn);
  });


  socket.on('message', function (messageX, fn) {
    // socket.limiter.removeTokens(1, function(err, remainingRequests) {
    skynet.throttles.message.rateLimit(socket.id, function (err, limited) {
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
              getDevice(socket, function(err, device){
                if(device.secure){
                  if(config.tls){
                    skynet.ios.sockets.socket(target).send(message);
                  }
                } else {
                  //console.log('socket lookup', io.sockets.socket(target));
                  skynet.io.sockets.socket(target).send(message);
                }
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
          getDevice(socket, function(err, fromDevice){
            if(fromDevice){
              message.api = "message";
              skynet.sendMessage(fromDevice, message, fn);
            }
          });
        }

      }
    });

  });

}


module.exports = socketLogic;
