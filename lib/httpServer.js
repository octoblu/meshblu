'use strict';
var _ = require('lodash');
var http = require('http');
var https = require('https');
var express = require('express');
var cors = require('cors');
var bodyParser = require('body-parser');
var meshbluHealthcheck = require('express-meshblu-healthcheck');
var socketio = require('socket.io');
var WebSocket = require('faye-websocket');
var proxyListener = require('./proxyListener');
var setupRestfulRoutes = require('./setupHttpRoutes');
var setupMqttClient = require('./setupMqttClient');
var socketLogic = require('./socketLogic');
var MeshbluWebsocketHandler = require('./MeshbluWebsocketHandler');
var sendMessageCreator = require('./sendMessage');
var wrapMqttMessage = require('./wrapMqttMessage');
var createSocketEmitter = require('./createSocketEmitter');
var sendActivity = require('./sendActivity');
var sendConfigActivity = require('./sendConfigActivity');
var throttles = require('./getThrottles');
var fs = require('fs');
var parentConnection = require('./getParentConnection');
var skynetClient = require('skynet');
var MessageIO = require('./MessageIO');

var httpServer = function(config, parentConnection) {
  var useHTTPS = config.tls && config.tls.cert;

  // Instantiate our two servers (http & https)
  var app = express();
  var server = http.createServer(app);

  if(useHTTPS){

    // Setup some https server options
    var https_options = {
      cert: fs.readFileSync(config.tls.cert),
      key: fs.readFileSync(config.tls.key)
    };

    var https_server = https.createServer(https_options, app);
  }

  if (config.useProxyProtocol) {
    proxyListener.resetListeners(server);
    if(useHTTPS){
      proxyListener.resetListeners(server);
    }
  }

  // Setup websockets
  server.on('upgrade', function(request, socket, body) {
    if (WebSocket.isWebSocket(request) && request.url == '/ws/v2') {
      var ws = new WebSocket(request, socket, body);
      var websocketHandler = new MeshbluWebsocketHandler({
        sendMessage: sendMessage
      });
      websocketHandler.initialize(ws, request);
    }
  })

  // Setup socket.io
  var io, ios, messageIO, redisStore;
  io = socketio(server);
  messageIO = new MessageIO(); // internal message bus
  messageIO.start();
  if(config.redis && config.redis.host){
    var redis = require('./redis');
    redisStore = redis.createIoStore();
    io.adapter(redisStore);
    messageIO.setAdapter(redisStore);
  }

  if(useHTTPS){
    ios = socketio(https_server);
    if(config.redis && config.redis.host){
      ios.adapter(redisStore);
    }
  }

  app.use(cors());
  app.use(meshbluHealthcheck());
  app.use(bodyParser.json({limit : '50mb'}));
  app.use(bodyParser.urlencoded({limit: '50mb', extended : true}));

  // merge all params
  app.use(function(request, response, next) {
    request.merged_params = _.extend({}, request.query, request.body, request.params);
    next();
  });

  var socketEmitter = createSocketEmitter(io, ios);

  function mqttEmitter(uuid, wrappedData, options){
    if(mqttclient){
      mqttclient.publish(uuid, wrappedData, options);
    }
  }

  var sendMessage = sendMessageCreator(socketEmitter, mqttEmitter, parentConnection);
  if(parentConnection){
    parentConnection.on('message', function(data, fn){
      if(data){
        var devices = data.devices;
        if (!_.isArray(devices)) {
          devices = [devices];
        }
        _.each(devices, function(device) {
          if(device !== config.parentConnection.uuid){
            sendMessage({uuid: data.fromUuid}, data, fn);
          }
        });
      }
    });
  }

  function emitToClient(topic, device, msg){
    if(device.protocol === "mqtt"){
      // MQTT handler
      mqttEmitter(device.uuid, wrapMqttMessage(topic, msg), {qos:msg.qos || 0});
    }
    else{
      socketEmitter(device.uuid, topic, msg);
    }
  }

  var skynet = {
    sendMessage: sendMessage,
    sendActivity: sendActivity,
    sendConfigActivity: sendConfigActivity,
    throttles: throttles,
    io: io,
    ios: ios,
    messageIO: messageIO,
    emitToClient: emitToClient
  };

  function checkConnection(socket, secure){
    var ip = socket.handshake.headers["x-forwarded-for"] || socket.request.connection.remoteAddress;

    if(_.contains(throttles.unthrottledIps, ip)){
      socket.throttled = false;
      socketLogic(socket, secure, skynet);
    }else{
      socket.throttled = true;
      throttles.connection.rateLimit(ip, function (err, limited) {
        if(limited){
          socket.emit('notReady',{error: 'rate limit exceeded ' + ip});
          socket.disconnect();
        }else{
          socketLogic(socket, secure, skynet);
        }
      });
    }
  }

  io.on('connection', function (socket) {
    checkConnection(socket, false);
  });

  if(useHTTPS){
    ios.on('connection', function (socket) {
      checkConnection(socket, true);
    });
  }

  var mqttclient = setupMqttClient(skynet, config);

  // Now, setup both servers in one step
  setupRestfulRoutes(app, skynet);

  var serverPort = process.env.PORT || config.port;
  server.listen(serverPort, function() {
    console.log('HTTP listening at 0.0.0.0:%s', serverPort);
  });

  if(useHTTPS){
    var sslPort = process.env.SSLPORT || config.tls.sslPort;
    https_server.listen(sslPort, function() {
      console.log('HTTPS listening at 0.0.0.0:%s', sslPort);
    });
  }
};

module.exports = httpServer;
