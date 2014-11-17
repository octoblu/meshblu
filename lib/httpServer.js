'use strict';
var _ = require('lodash');
var restify = require('restify');
var socketio = require('socket.io');
var proxyListener = require('./proxyListener');
var setupRestfulRoutes = require('./setupHttpRoutes');
var setupMqttClient = require('./setupMqttClient');
var socketLogic = require('./socketLogic');
var sendMessageCreator = require('./sendMessage');
var wrapMqttMessage = require('./wrapMqttMessage');
var createSocketEmitter = require('./createSocketEmitter');
var sendActivity = require('./sendActivity');
var sendConfigActivity = require('./sendConfigActivity');
var throttles = require('./getThrottles');
var fs = require('fs');
var setupGatewayConfig = require('./setupGatewayConfig');
var parentConnection = require('./getParentConnection');
var skynetClient = require("skynet");

var httpServer = function(config, parentConnection) {
  var useHTTPS = config.tls && config.tls.cert;

  // Instantiate our two servers (http & https)
  var server = restify.createServer();
  server.pre(restify.pre.sanitizePath());

  if(useHTTPS){

    // Setup some https server options
    var https_options = {
      certificate: fs.readFileSync(config.tls.cert),
      key: fs.readFileSync(config.tls.key)
    };

    var https_server = restify.createServer(https_options);
    https_server.pre(restify.pre.sanitizePath());
  }

  if (config.useProxyProtocol) {
    proxyListener.resetListeners(server.server);
    if(useHTTPS){
      proxyListener.resetListeners(https_server.server);
    }
  }

  // Setup websockets
  var io, ios, redisStore;
  io = socketio(server.server);
  if(config.redis && config.redis.host){
    var redis = require('./redis');
    redisStore = redis.createIoStore();
    io.adapter(redisStore);
  }

  if(useHTTPS){
    ios = socketio(https_server.server);
    if(config.redis && config.redis.host){
      ios.adapter(redisStore);
    }
  }

  restify.CORS.ALLOW_HEADERS.push('skynet_auth_uuid');
  restify.CORS.ALLOW_HEADERS.push('skynet_auth_token');
  restify.CORS.ALLOW_HEADERS.push('meshblu_auth_uuid');
  restify.CORS.ALLOW_HEADERS.push('meshblu_auth_token');
  restify.CORS.ALLOW_HEADERS.push('accept');
  restify.CORS.ALLOW_HEADERS.push('sid');
  restify.CORS.ALLOW_HEADERS.push('lang');
  restify.CORS.ALLOW_HEADERS.push('origin');
  restify.CORS.ALLOW_HEADERS.push('withcredentials');
  restify.CORS.ALLOW_HEADERS.push('x-requested-with');

  // http params
  server.use(restify.queryParser());
  server.use(restify.bodyParser());
  server.use(restify.CORS({ headers: [ 'skynet_auth_uuid', 'skynet_auth_token', 'meshblu_auth_uuid', 'meshblu_auth_token' ], origins: ['*:*'] }));
  server.use(restify.fullResponse());

  // https params
  if (useHTTPS) {
    https_server.use(restify.queryParser());
    https_server.use(restify.bodyParser());
    https_server.use(restify.CORS({ headers: [ 'skynet_auth_uuid', 'skynet_auth_token', 'meshblu_auth_uuid', 'meshblu_auth_token' ], origins: ['*:*'] }));
    https_server.use(restify.fullResponse());
  }

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
    gateway : setupGatewayConfig(emitToClient),
    sendActivity: sendActivity,
    sendConfigActivity: sendConfigActivity,
    throttles: throttles,
    io: io,
    ios: ios,
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
  setupRestfulRoutes(server, skynet);

  if(useHTTPS){
    setupRestfulRoutes(https_server, skynet);
  }

  var serverPort = process.env.PORT || config.port;
  server.listen(serverPort, function() {
    console.log('HTTP listening at %s', server.url);
  });

  if(useHTTPS){
    https_server.listen(process.env.SSLPORT || config.tls.sslPort, function() {
      console.log('HTTPS listening at %s', https_server.url);
    });
  }
};

module.exports = httpServer;
