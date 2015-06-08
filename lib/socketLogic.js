var _ = require('lodash');
var whoAmI = require('./whoAmI');
var config = require('../config');
var getData = require('./getData');
var logData = require('./logData');
var logEvent = require('./logEvent');
var register = require('./register');
var getEvents = require('./getEvents');
var getDevices = require('./getDevices');
var resetToken = require('./resetToken');
var authDevice = require('./authDevice');
var unregister = require('./unregister');
var claimDevice = require('./claimDevice');
var getPublicKey = require('./getPublicKey');
var securityImpl = require('./getSecurityImpl');
var createActivity = require('./createActivity');
var updateSocketId = require('./updateSocketId');
var updatePresence = require('./updatePresence');
var getLocalDevices = require('./getLocalDevices');
var getSystemStatus = require('./getSystemStatus');
var updateFromClient = require('./updateFromClient');
var generateAndStoreToken = require('./generateAndStoreToken');
var debug = require('debug')('meshblu:socketLogic');
var MessageIOClient = require('./messageIOClient');

function getActivity(topic, socket, device, toDevice){
  return createActivity(topic, socket.ipAddress, device, toDevice);
}

function getDevice(socket, callback) {
  if(socket.skynetDevice){
    whoAmI(socket.skynetDevice.uuid, true, function(device) {
      return callback(null, device);
    });
  }else{
    return callback(new Error('skynetDevice not found for socket' + socket), null);
  }
}

function socketLogic (socket, secure, skynet){
  var ipAddress = socket.handshake.headers['x-forwarded-for'] || socket.request.connection._peername.address;

  debug("connected", socket.id);

  socket.ipAddress = ipAddress;
  logEvent(100, {socketid: socket.id, protocol: 'websocket'});

  socket.emit('identify', { socketid: socket.id });
  socket.on('identity', function (data) {
    data = _.extend({}, data, {
      socketid: socket.id,
      ipAddress: ipAddress,
      secure: secure,
      online: true
    });
    if(!data.protocol){
      data.protocol = 'websocket';
    }
    updateSocketId(data, function(auth){

      if (auth.status != 201){
        socket.emit('notReady', {api: 'connect', status: auth.status, uuid: data.uuid});
        return
      }

      socket.skynetDevice = auth.device;

      var readyMessage = {
        api: 'connect',
        status: auth.status,
        socketid: socket.id,
        uuid: auth.device.uuid,
        token: data.token
      };

      if (data.uuid !== auth.device.uuid) {
        readyMessage.token = auth.device.token;
      }

      socket.emit('ready', readyMessage);

      //Announce presence online
      var message = {
        devices: '*',
        topic: 'device-status',
        payload: {
          online: true
        }
      };
      skynet.sendMessage(auth.device, message);

      debug('setting up message bus', socket.id);
      socket.messageIOClient = new MessageIOClient();
      socket.messageIOClient.on('message', function(message){
        debug(socket.id, 'relay message', message, socket.skynetDevice.uuid);
        socket.emit('message', message);
      });

      socket.messageIOClient.on('data', function(message){
        debug(socket.id, 'relay data', message, socket.skynetDevice.uuid);
        socket.emit('data', message);
      });

      socket.messageIOClient.on('config', function(message){
        debug(socket.id, 'relay config', message);
        socket.emit('config', message);
      });

      socket.messageIOClient.start()

      // Have device join its uuid room name so that others can subscribe to it
      debug(socket.id, 'subscribing to received and broadcast', auth.device.uuid);
      socket.messageIOClient.subscribe(auth.device.uuid, ['received', 'broadcast']);

      whoAmI(data.uuid, false, function(results){
        data.auth = auth;
        data.fromUuid = results.uuid;
        data.from = _.pick(results, config.preservedDeviceProperties);
        logEvent(101, data);
      });
    });
  });

  socket.on('disconnect', function (data) {
    debug('disconnecting', socket.id);
    if (socket.messageIOClient) {
      socket.messageIOClient.close()
    }
    updatePresence(socket.id);
    // Emit API request from device to room for subscribers
    getDevice(socket, function(err, device){
      //Announce presence offline
      var message = {
        devices: '*',
        topic: 'device-status',
        payload: {online: false}
      };
      skynet.sendMessage(device, message);

      logEvent(102, {api: "disconnect", socketid: socket.id, device: device});
    });
  });

  socket.on('subscribe', function(message, fn) {
      fn = fn || _.noop;
      if(!message) {
        return fn({error: "not enough information to subscribe"});
      }

      var subscriptionTypes = []

      if(message.token) {
        authDevice(message.uuid, message.token, function(error, authedDevice) {
          if (!authedDevice || error) {
            return;
          }
          subscriptionTypes.push('broadcast');
          subscriptionTypes.push('received');
          subscriptionTypes.push('sent');
          socket.messageIOClient.subscribe(message.uuid, message.types || subscriptionTypes);
          return;
        });
      }

      getDevice(socket, function(err, subscribingDevice) {
        skynet.sendActivity(getActivity('subscribe', socket, subscribingDevice));

        if(err) {
          return fn({error: "can't get subscribingDevice"});
        }

        whoAmI(message.uuid, false, function(device) {
          if(device.error){
            return fn(device);
          }

          message.toUuid = device.uuid;
          message.to = _.pick(device, config.preservedDeviceProperties);
          logEvent(204, message);

          securityImpl.canReceive(subscribingDevice, device, function(error, permission) {
            if(error) {
              debug('subscribe', 'fromDevice', subscribingDevice, 'toDevice', device, "can't receive");
              return fn({error: "unauthorized access"});
            }

            if (permission) {
              subscriptionTypes.push('broadcast');
            }

            if(device.owner == subscribingDevice.uuid){
              subscriptionTypes.push('received');
              subscriptionTypes.push('sent');
            }

            socket.messageIOClient.subscribe(message.uuid, message.types || subscriptionTypes);
            fn({"api": "subscribe", "socketid": socket.id, "toUuid": message.uuid, "result": true});
          });
        });
      });
  });

  socket.on('unsubscribe', function(data, fn) {
    fn = fn || _.noop
    socket.messageIOClient.unsubscribe(data.uuid);
    socket.messageIOClient.unsubscribe(data.uuid + '_bc');
    socket.messageIOClient.unsubscribe(data.uuid + '_sent');

    getDevice(socket, function(err, device){
      skynet.sendActivity(getActivity('unsubscribe', socket, device));
      if(err){ return; }
      data.fromUuid = device.uuid;
      data.from = _.pick(device, config.preservedDeviceProperties);
      logEvent(205, data);
    });
    try{
      fn({"api": "unsubscribe", "uuid": data.uuid});
    } catch (e){
      console.error(e);
    }
  });

  // APIs
  socket.on('status', function (fn) {
    fn = fn || _.noop
    skynet.throttles.query.rateLimit(socket.id, function (err, limited) {
      if(socket.throttled && limited){
        console.log('status throttled', socket.id);
        try {
          fn({error: {message: 'Rate Limit Exceeded', code: 429}});
        } catch (e) {
        }
        return;
      }else{

        // Emit API request from device to room for subscribers
        getDevice(socket, function(err, device){
          skynet.sendActivity(getActivity('status', socket, device));
          if(err){ return; }
          // socket.broadcast.to(uuid).emit('message', {"api": "status"});

          getSystemStatus(function(results){

            results.fromUuid = device.uuid;
            results.from = _.pick(device, config.preservedDeviceProperties);
            logEvent(200, results);
            try{
              fn(results);
            } catch (e){
              console.error(e);
            }
          });
        });
      }
    });
  });


  socket.on('device', function (data, fn) {
    fn = fn || _.noop
    skynet.throttles.query.rateLimit(socket.id, function (err, limited) {
      if(socket.throttled && limited){
        console.log('query throttled', socket.id);
        try {
          fn({error: {message: 'Rate Limit Exceeded', code: 429}});
        } catch (e) {
        }
        return;
      }else{

        if(!data || (typeof data != 'object')){
          data = {};
        }

        getDevice(socket, function(err, device){
          skynet.sendActivity(getActivity('device', socket, device));
          if(err){ return; }
          var reqData = data;
          getDevices(device, data, false, function(results){
            var msg = {
              fromUuid : device.uuid,
              from : device,
              device: _.first(results.devices)
            };
            logEvent(403, msg);

            try{
              fn(msg);
            } catch (e){
              console.error(e);
            }
          });
        });
      }
    });
  });

  socket.on('devices', function (data, fn) {
    fn = fn || _.noop
    skynet.throttles.query.rateLimit(socket.id, function (err, limited) {
      if(socket.throttled && limited){
        console.log('query throttled', socket.id);
        try {
          fn({error: {message: 'Rate Limit Exceeded', code: 429}});
        } catch (e) {
        }
        return;
      }else{

        if(!data || (typeof data != 'object')){
          data = {};
        }

        getDevice(socket, function(err, device){
          skynet.sendActivity(getActivity('devices', socket, device));
          if(err){ return; }
          var reqData = data;
          getDevices(device, data, false, function(results){
            results.fromUuid = device.uuid;
            results.from = _.pick(device, config.preservedDeviceProperties);
            logEvent(403, results);

            try{
              fn(results);
            } catch (e){
              console.error(e);
            }
          });
        });
      }
    });
  });

  socket.on('mydevices', function (data, fn) {
    fn = fn || _.noop
    data = data || {};

    skynet.throttles.query.rateLimit(socket.id, function (err, limited) {
      if(socket.throttled && limited){
        console.log('query throttled', socket.id);
        try {
          fn({error: {message: 'Rate Limit Exceeded', code: 429}});
        } catch (e) {
        }
        return;
      }else{
        getDevice(socket, function(err, device){
          skynet.sendActivity(getActivity('mydevices', socket, device));
          if(err){ return; }
          data.owner = device.uuid;
          getDevices(device, data, true, function(results){
            try{
              results.fromUuid = device.uuid;
              results.from = _.pick(device, config.preservedDeviceProperties);
              logEvent(403, results);
              fn(results);
            } catch (e){
              console.error(e);
            }
          });
        });
      }
    });
  });

  socket.on('localdevices', function (data, fn) {
    fn = fn || _.noop
    skynet.throttles.query.rateLimit(socket.id, function (err, limited) {
      if(socket.throttled && limited){
        console.log('query throttled', socket.id);
        try {
          fn({error: {message: 'Rate Limit Exceeded', code: 429}});
        } catch (e) {
        }
        return;
      }else{

        if(!data || (typeof data != 'object')){
          data = {};
        }
        // Emit API request from device to room for subscribers
        getDevice(socket, function(err, device){
          skynet.sendActivity(getActivity('localdevices', socket, device));
          if(err){ return; }
          getLocalDevices(device, false, function(results){
            results.fromUuid = device.uuid;
            results.from = _.pick(device, config.preservedDeviceProperties);
            logEvent(403, results);

            try{
              fn(results);
            } catch (e){
              console.error(e);
            }
          });
        });
      }
    });
  });

  socket.on('unclaimeddevices', function (data, fn) {
    fn = fn || _.noop
    skynet.throttles.query.rateLimit(socket.id, function (err, limited) {
      if(socket.throttled && limited){
        console.log('query throttled', socket.id);
        try {
          fn({error: {message: 'Rate Limit Exceeded', code: 429}});
        } catch (e) {
        }
        return;
      }else{

        if(!data || (typeof data != 'object')){
          data = {};
        }
        // Emit API request from device to room for subscribers
        getDevice(socket, function(err, device){
          skynet.sendActivity(getActivity('localdevices', socket, device));
          if(err){ return; }
          getLocalDevices(device, true, function(results){
            results.fromUuid = device.uuid;
            results.from = _.pick(device, config.preservedDeviceProperties);
            logEvent(403, results);

            try{
              fn(results);
            } catch (e){
              console.error(e);
            }
          });
        });
      }
    });
  });

  socket.on('claimdevice', function (data, fn) {
    fn = fn || _.noop
    skynet.throttles.query.rateLimit(socket.id, function (err, limited) {
      if(socket.throttled && limited){
        console.log('query throttled', socket.id);
        try {
          fn({error: {message: 'Rate Limit Exceeded', code: 429}});
        } catch (e) {
        }
        return;
        return;
      }

      if(!data || (typeof data != 'object')){
        data = {};
      }
      // Emit API request from device to room for subscribers
      getDevice(socket, function(err, device){
        skynet.sendActivity(getActivity('claimdevice', socket, device));
        if(err){ return; }
        claimDevice(device, data, function(err, results){
          logEvent(403, {error: (err && err.message), results: results, fromUuid: device.uuid, from: device});

          try{
            fn({error: (err && err.message), results: results});
          } catch (e){
            console.error(e);
          }
        });
      });
    });
  });

  socket.on('whoami', function (data, fn) {
    fn = fn || _.noop

    skynet.throttles.whoami.rateLimit(socket.id, function (err, limited) {
      if(socket.throttled && limited){
        console.log('whoami throttled', socket.id);
        try {
          fn({error: {message: 'Rate Limit Exceeded', code: 429}});
        } catch (e) {
        }
        return;
      }else{
        getDevice(socket, function(err, device){
          skynet.sendActivity(getActivity('whoami', socket, device));
          if(err){ return; }
          try{
            fn(device);
          } catch (e){
            console.error(e);
          }
        });

      }
    });

  });


  socket.on('register', function (data, fn) {
    fn = fn || _.noop
    debug('register', data, fn);
    data = data || {};

    skynet.sendActivity(getActivity('register', socket));
    data.socketid = socket.id;
    data.ipAddress = data.ipAddress || ipAddress;
    debug('socketLogic:registering');

    register(data, function(error, device){
      try{
        fn(device);
      } catch (e){
        console.error(e);
      }
    });
  });

  socket.on('update', function (data, fn) {
    fn = fn || _.noop
    if(!data){
      data = {};
    }
    // Emit API request from device to room for subscribers
    getDevice(socket, function(err, fromDevice){
      skynet.sendActivity(getActivity('update', socket, fromDevice));
      if(err){ return; }

      updateFromClient(fromDevice, data, function(regData) {
        skynet.sendConfigActivity(data.uuid, skynet.emitToClient);
        try {
          fn(regData);
        } catch(error) {
          console.error(error);
        }
      });
    });
  });

  socket.on('unregister', function (data, fn) {
    fn = fn || _.noop
    if(!data){
      data = {};
    }
    // Emit API request from device to room for subscribers
    getDevice(socket, function(err, fromDevice){
      if(err){ return; }
      var reqData = data;
      skynet.sendActivity(getActivity('unregister', socket, fromDevice));
      unregister(fromDevice, data.uuid, data.token, skynet.emitToClient, function(results){
        if(results == null || results == undefined){
          results = {};
        }
        results.fromUuid = fromDevice.uuid;
        results.from = _.pick(fromDevice, config.preservedDeviceProperties);
        logEvent(402, results);

        try{
          fn(results);
        } catch (e){
          console.error(e);
        }
      });
    });
  });

  socket.on('events', function(data, fn) {
    fn = fn || _.noop
    authDevice(data.uuid, data.token, function(error, authedDevice){
      if(!authedDevice){
          var results = {"api": "events", "result": false};

          try{
            fn(results);
          } catch (e){
            console.error(e);
          }
          return;
      }

      // Emit API request from device to room for subscribers
      getDevice(socket, function(err, device){
        skynet.sendActivity(getActivity('events', socket, device));
        if(err){ return; }
        var reqData = data;
        reqData.api = "events";

        getEvents(data.uuid, function(results){
          try{
            fn(results);
          } catch (e){
            console.error(e);
          }
          return;
        });
      });
    });
  });

  socket.on('authenticate', function(data, fn) {
    fn = fn || _.noop
    skynet.sendActivity(getActivity('authenticate', socket));

    authDevice(data.uuid, data.token, function(error, authedDevice){
      var results;
      if (!authedDevice) {
        try{
          fn({"uuid": data.uuid, "authentication": false});
        } catch (e){
          console.error(e);
        }
        return;
      }

      results = {"uuid": data.uuid, "authentication": true};

      data = _.extend({}, data, {
        socketid: socket.id,
        ipAddress: ipAddress,
        secure: secure,
        online: true
      });

      if(!data.protocol){
        data.protocol = "websocket";
      }

      updateSocketId(data, function() {
        socket.emit('ready', {"api": "connect", "status": 201, "socketid": socket.id, "uuid": data.uuid});
        socket.join(data.uuid);

        try{
          fn(results);
        } catch (e){
          console.error(e);
        }
      });

      whoAmI(data.uuid, false, function(check){
        results.toUuid = check.uuid;
        results.to = check;
        logEvent(102, results);
      });
    });
  });

  socket.on('data', function (messageX, fn) {
    fn = fn || _.noop
    skynet.throttles.data.rateLimit(socket.id, function (err, limited) {
      if(socket.throttled && limited){
        console.log('data throttled', socket.id);
        try {
          fn({error: {message: 'Rate Limit Exceeded', code: 429}});
        } catch (e) {
        }
        return;
      }else{
        var data = messageX;

        getDevice(socket, function(err, fromDevice){
          //skynet.sendActivity(getActivity('data', socket, fromDevice));
          if(err){ return; }

          if (data) {
            delete data.token;
          }

          logData(data, function(results){
            // Send messsage regarding data update
            var message = {};
            message.payload = data;
            // message.devices = data.uuid;
            message.devices = "*";

            skynet.sendMessage(fromDevice, message);

            try{
              fn(results);
            } catch (e){
              console.error(e);
            }
          });
        });
      }
    });
  });

  socket.on('getdata', function (data, fn) {
    fn = fn || _.noop
    skynet.throttles.query.rateLimit(socket.id, function (err, limited) {
      if(socket.throttled && limited){
        console.log('query throttled', socket.id);
        try {
          fn({error: {message: 'Rate Limit Exceeded', code: 429}});
        } catch (e) {
        }
        return;
      }

      skynet.sendActivity(getActivity('getdata', socket));
      authDevice(data.uuid, data.token, function(error, authedDevice){
        if(!authedDevice) {
          var results = {"api": "getdata", "result": false};

          try{
            fn(results);
          } catch (e){
            console.error(e);
          }
          return;
        }

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
          if (results) {
            results.fromUuid = socket.skynetDevice.uuid;
          }

          try{
            fn(results);
          } catch (e){
            console.error(e);
          }
        });
      });
    });
  });

  socket.on('messageAck', function (data) {
    getDevice(socket, function(err, fromDevice){
      skynet.sendActivity(getActivity('messageAck', socket, fromDevice));
      if(fromDevice){
        whoAmI(data.devices, false, function(check){
          data.fromUuid = fromDevice.uuid;

          if(check.error){
            return;
          }
          securityImpl.canSend(fromDevice, check, function(error, permission){
            if(error || !permission){
              debug('messageAck', 'fromDevice', fromDevice, 'toDevice', check, "can't send");
              return;
            }
            skynet.emitToClient('messageAck', check, data);
          });
        });
      }
    });
  });


  socket.on('tb', function (messageX) {
    skynet.throttles.message.rateLimit(socket.id, function (err, limited) {
      var message = messageX;

      if (socket.throttled && limited) {
        // TODO: Emit rate limit exceeded message
        console.log("Rate limit exceeded for socket:", socket.id);
        console.log("message", message);
      } else {
        if(!message){
          return;
        }else{
          message = message.toString();

          // Broadcast to room for pubsub
          getDevice(socket, function(err, fromDevice){
            //skynet.sendActivity(getActivity('tb', socket, fromDevice));
            if(fromDevice){
              skynet.sendMessage(fromDevice, {payload: message}, 'tb');
            }
          });
        }
      }
    });
  });

  socket.on('message', function (messageX) {

    // socket.limiter.removeTokens(1, function(err, remainingRequests) {
    skynet.throttles.message.rateLimit(socket.id, function (err, limited) {
      var message = messageX;

      if (socket.throttled && limited) {
        // TODO: Emit rate limit exceeded message
        console.log("Rate limit exceeded for socket:", socket.id);
        console.log("message", message);
      } else {
        if(typeof message !== 'object'){
          return;
        }else{
          // Broadcast to room for pubsub
          getDevice(socket, function(err, fromDevice){
            //skynet.sendActivity(getActivity('message', socket, fromDevice));
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
    skynet.throttles.message.rateLimit(socket.id, function (err, limited) {
      var message = messageX;

      if (socket.throttled && limited) {
        // TODO: Emit rate limit exceeded message
        console.log("Rate limit exceeded for socket:", socket.id);
        console.log("message", message);
      } else {
        getDevice(socket, function(err, fromDevice){
          if(fromDevice){
            skynet.sendMessage(fromDevice, message, 'tb');
          }
        });
      }
    });
  });

  socket.on('getPublicKey', getPublicKey);

  socket.on('resetToken', function(message, fn){
    fn = fn || _.noop
    skynet.throttles.message.rateLimit(socket.id, function (err, limited) {
      if (socket.throttled && limited) {
        // TODO: Emit rate limit exceeded message
        console.log("Rate limit exceeded for socket:", socket.id);
        console.log("message", message);
        return;
      }
      getDevice(socket, function(err, fromDevice){
        if(err){ return; }
          resetToken(fromDevice, message.uuid, skynet.emitToClient, function(error, token){
            if(error) {
              return socket.emit('error', {method: 'resetToken', error: error});
            }
            fn({uuid: message.uuid, token: token});
          });
      });
    });
  });

  socket.on('generateAndStoreToken', function(message, fn){
    getDevice(socket, function(err, fromDevice){
      if(err){ return console.error(err); }
      generateAndStoreToken(fromDevice, message.uuid, function(error, result){
        if(error) {
          fn();
          return;
        }
        fn({uuid: message.uuid, token: result.token});
      });
    });
  });
}

module.exports = socketLogic;
