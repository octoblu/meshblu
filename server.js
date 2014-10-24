var _ = require('lodash');
var app = require('commander');
var config = require('./config');
var restify = require('restify');
var socketio = require('socket.io');
var proxyListener = require('./proxyListener');
var redis = require('./lib/redis');
var setupRestfulRoutes = require('./lib/setupHttpRoutes');
var setupMqttClient = require('./lib/setupMqttClient');
var socketLogic = require('./lib/socketLogic');
var sendMessageCreator = require('./lib/sendMessage');
var wrapMqttMessage = require('./lib/wrapMqttMessage');
var createSocketEmitter = require('./lib/createSocketEmitter');
var sendActivity = require('./lib/sendActivity');
var sendConfigActivity = require('./lib/sendConfigActivity');
var throttles = require('./lib/getThrottles');
var fs = require('fs');
var setupGatewayConfig = require('./lib/setupGatewayConfig');
var parentConnection = require('./lib/getParentConnection');
var useHTTPS = config.tls && config.tls.cert;
var skynetClient = require("skynet");

if (process.env.AIRBRAKE_KEY) {
  var airbrakeErrors = require("./lib/airbrakeErrors");
  airbrakeErrors.handleExceptions()
} else {
  process.on("uncaughtException", function(error) {
    return console.error(error.message, error.stack);
  });
}

throw new Error("SUP");

if(config.parentConnection){
  parentConnection = skynetClient.createConnection(config.parentConnection);
  parentConnection.on('notReady', function(data){
    console.log('Failed authenitication to parent cloud', data);
  });

  parentConnection.on('ready', function(data){
    console.log('UUID authenticated for parent cloud connection.', data);
  });

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

// sudo NODE_ENV=production forever start server.js --environment production
app
  .option('-e, --environment', 'Set the environment (defaults to development)')
  .parse(process.argv);

if(app.args[0]){
  app.environment = app.args[0];
} else if(process.env.NODE_ENV){
  app.environment = process.env.NODE_ENV;
} else {
  app.environment = 'development';
}

config.rateLimits = config.rateLimits || {};

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
var io, ios;
io = socketio(server);
var redisStore;
if(config.redis && config.redis.host){
  redisStore = redis.createIoStore();
  io.adapter(redisStore);
}

if(useHTTPS){
  ios = socketio(https_server);
  if(config.redis && config.redis.host){
    ios.adapter(redisStore);
  }
}

restify.CORS.ALLOW_HEADERS.push('skynet_auth_uuid');
restify.CORS.ALLOW_HEADERS.push('skynet_auth_token');
restify.CORS.ALLOW_HEADERS.push('accept');
restify.CORS.ALLOW_HEADERS.push('sid');
restify.CORS.ALLOW_HEADERS.push('lang');
restify.CORS.ALLOW_HEADERS.push('origin');
restify.CORS.ALLOW_HEADERS.push('withcredentials');
restify.CORS.ALLOW_HEADERS.push('x-requested-with');

// http params
server.use(restify.queryParser());
server.use(restify.bodyParser());
server.use(restify.CORS({ headers: [ 'skynet_auth_uuid', 'skynet_auth_token' ], origins: ['*'] }));
server.use(restify.fullResponse());

// https params
if (useHTTPS) {
  https_server.use(restify.queryParser());
  https_server.use(restify.bodyParser());
  https_server.use(restify.CORS({ headers: [ 'skynet_auth_uuid', 'skynet_auth_token' ], origins: ['*'] }));
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

var qos = 0;
var mqttclient = setupMqttClient(skynet, config);

// Now, setup both servers in one step
setupRestfulRoutes(server, skynet);

if(useHTTPS){
  setupRestfulRoutes(https_server, skynet);
}

console.log("\nMM    MM              hh      bb      lll         ");
console.log("MMM  MMM   eee   sss  hh      bb      lll uu   uu ");
console.log("MM MM MM ee   e s     hhhhhh  bbbbbb  lll uu   uu ");
console.log("MM    MM eeeee   sss  hh   hh bb   bb lll uu   uu ");
console.log("MM    MM  eeeee     s hh   hh bbbbbb  lll  uuuu u ");
console.log("                 sss                              ");
console.log('\Meshblu (formerly skynet.im) %s environment loaded... ', app.environment);

var serverPort = process.env.PORT || config.port;
server.listen(serverPort, function() {
  console.log('HTTP listening at %s', server.url);
});

if(useHTTPS){
  https_server.listen(process.env.SSLPORT || config.tls.sslPort, function() {
    console.log('HTTPS listening at %s', https_server.url);
  });
}

try{
  //optional dependency for private clouds that can broadcast their presence locally.
  var mdns = require('mdns');
  var ad = mdns.createAdvertisement(mdns.tcp('meshblu'), parseInt(serverPort, 10));
  ad.start();
}catch(mdnsE){
  //console.log('mdns', mdnsE);
}
