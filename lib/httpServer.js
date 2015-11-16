'use strict';
var _ = require('lodash');
var http = require('http');
var https = require('https');
var express = require('express');
var cors = require('cors');
var bodyParser = require('body-parser');
var morgan = require('morgan');
var meshbluHealthcheck = require('express-meshblu-healthcheck');
var SocketIO = require('socket.io');
var WebSocket = require('faye-websocket');
var proxyListener = require('./proxyListener');
var setupRestfulRoutes = require('./setupHttpRoutes');
var socketLogic = require('./socketLogic');
var MeshbluEventEmitter = require('./MeshbluEventEmitter');
var MeshbluWebsocketHandler = require('./MeshbluWebsocketHandler');
var MeshbluSocketIOHandler = require('./MeshbluSocketIOHandler');
var sendMessageCreator = require('./sendMessage');
var createMessageIOEmitter = require('./createMessageIOEmitter');
var sendActivity = require('./sendActivity');
var throttles = require('./getThrottles');
var fs = require('fs');
var debug = require('debug')('meshblu:server:httpServer');
var parentConnection = require('./getParentConnection');
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
      proxyListener.resetListeners(https_server);
    }
  }

  var setupWebsocket = function(request, socket, body) {
    if (WebSocket.isWebSocket(request) && request.url == '/ws/v2') {
      var meshbluEventEmitter = new MeshbluEventEmitter(config.uuid, config.forwardEventUuids, sendMessage);
      var ws = new WebSocket(request, socket, body);
      var websocketHandler = new MeshbluWebsocketHandler({
        sendMessage: sendMessage,
        meshbluEventEmitter: meshbluEventEmitter
      });
      websocketHandler.initialize(ws, request);
    }
  };

  // Setup websockets
  server.on('upgrade', setupWebsocket);
  if (useHTTPS) {
    https_server.on('upgrade', setupWebsocket);
  }

  // Setup socket.io
  var io, io2, ios, messageIO, redisStore;
  io = new SocketIO(server);
  io2 = new SocketIO(server, {path: '/socket.io/v2'});
  messageIO = new MessageIO(); // internal message bus
  messageIO.start();
  if(config.redis && config.redis.host){
    var redis = require('./redis');
    redisStore = redis.createIoStore();
    messageIO.setAdapter(redisStore);
  }

  if(useHTTPS){
    ios = new SocketIO(https_server);
  }

  app.set('trust proxy', true);
  app.use(cors({origin: true, credentials: true}));
  app.use(morgan('combined', {immediate: false}));
  app.use(meshbluHealthcheck());
  app.use(bodyParser.json({limit : '50mb'}));
  app.use(bodyParser.urlencoded({limit: '50mb', extended : true}));

  // merge all params
  app.use(function(request, response, next) {
    request.merged_params = _.extend({}, request.query, request.body);
    next();
  });

  var socketEmitter = createMessageIOEmitter(messageIO.io);

  var sendMessage = sendMessageCreator(socketEmitter, _.noop, parentConnection);
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
    socketEmitter(device.uuid, topic, msg);
  }

  var skynet = {
    sendMessage: sendMessage,
    sendActivity: sendActivity,
    throttles: throttles,
    messageIO: messageIO,
    emitToClient: emitToClient
  };

  function checkConnection(socket, secure){
    socket.throttled = true;
    socketLogic(socket, secure, skynet);
  }

  io.on('connection', function (socket) {
    checkConnection(socket, false);
  });

  io2.on('connection', function(socket){
    var ip = socket.handshake.headers["x-forwarded-for"] || socket.request.connection.remoteAddress || socket.handshake.address;

    throttles.connection.rateLimit(ip, function (err, limited) {
      if (limited) {
        socket.emit('notReady',{error: {message: 'Rate Limit Exceeded', code: 429, ipAddress: ip}});
        socket.disconnect();
      } else {
        var meshbluEventEmitter = new MeshbluEventEmitter(config.uuid, config.forwardEventUuids, sendMessage);
        var meshbluSocketIOHandler = new MeshbluSocketIOHandler({meshbluEventEmitter: meshbluEventEmitter});
        meshbluSocketIOHandler.initialize(socket);
      }
    });
  })

  if(useHTTPS){
    ios.on('connection', function (socket) {
      checkConnection(socket, true);
    });
  }

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
