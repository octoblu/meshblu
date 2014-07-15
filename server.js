/* Setup command line parsing and options
 * See: https://github.com/visionmedia/commander.js
 */
var _ = require('lodash');
var app = require('commander');
var tokenthrottle = require("tokenthrottle");
var restify = require('restify');
var socketio = require('socket.io');
var skynetClient = require('skynet'); //skynet npm client

var config = require(process.env.SKYNET_CONFIG || './config');

var redis = require('./lib/redis');

var updateFromClient = require('./lib/updateFromClient');
var setupRestfulRoutes = require('./lib/setupHttpRoutes');
var setupCoapRoutes = require('./lib/setupCoapRoutes');
var setupMqttClient = require('./lib/setupMqttClient');
var socketLogic = require('./lib/socketLogic');
var sendMessageCreator = require('./lib/sendMessage');
var wrapMqttMessage = require('./lib/wrapMqttMessage');

var fs = require('fs');
var setupGatewayConfig = require('./lib/setupGatewayConfig');

var parentConnection;

if(config.parentConnection){
  //console.log('logging into parent cloud', config.parentConnection, skynetClient);
  parentConnection = skynetClient.createConnection(config.parentConnection);
  parentConnection.on('notReady', function(data){
    console.log('Failed authenitication to parent cloud', data);
  });

  parentConnection.on('ready', function(data){
    console.log('UUID authenticated for parent cloud connection.', data);
  });

  parentConnection.on('message', function(data, fn){
    if(data){
      console.log('on message', data);
      if(!Array.isArray(data.devices) && data.devices !== config.parentConnection.uuid){
        sendMessage({uuid: data.fromUuid}, data, fn);
      }
    }
  });
}

// sudo NODE_ENV=production forever start server.js --environment production
app
  .option('-e, --environment', 'Set the environment (defaults to development)')
  .parse(process.argv);

// console.log(app.environment || "running in development mode");
// if(!app.environment) app.environment = 'development';
if(app.args[0]){
  app.environment = app.args[0];
} else {
  app.environment = 'development';
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

config.rateLimits = config.rateLimits || {};
// rate per second
var throttles = {
  connection : tokenthrottle({rate: config.rateLimits.connection || 3}),
  message : tokenthrottle({rate: config.rateLimits.message || 10}),
  data : tokenthrottle({rate: config.rateLimits.data || 10}),
  query : tokenthrottle({rate: config.rateLimits.query || 2}),
  whoami : tokenthrottle({rate: config.rateLimits.whoami || 10}),
  unthrottledIps : config.rateLimits.unthrottledIps || []
};


// Instantiate our two servers (http & https)
var server = restify.createServer();
server.pre(restify.pre.sanitizePath());

if(config.tls){

  // Setup some https server options
  if(app.environment === 'development'){
    var https_options = {
      certificate: fs.readFileSync("../skynet_certs/server.crt"),
      key: fs.readFileSync("../skynet_certs/server.key")
    };
  } else {
    var https_options = {
      certificate: fs.readFileSync(config.tls.cert),
      key: fs.readFileSync(config.tls.key),
    };
  }

  var https_server = restify.createServer(https_options);
  https_server.pre(restify.pre.sanitizePath());
}

// Setup websockets
var io, ios;
io = socketio(server);
var redisStore;
var redisIoEmitter;
if(config.redis){
  if(config.redis){
    redisIoEmitter = require('socket.io-emitter')(redis.client);
  }
  redisStore = redis.createIoStore();
  io.adapter(redisStore);
}

if(config.tls){
  ios = socketio(https_server);
  if(config.redis){
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

// server.use(restify.acceptParser(server.acceptable));
server.use(restify.queryParser());
server.use(restify.bodyParser());
server.use(restify.CORS({ headers: [ 'skynet_auth_uuid', 'skynet_auth_token' ], origins: ['*'] }));
server.use(restify.fullResponse());

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


function socketEmitter(uuid, topic, data){
  //console.log('socketEmitter', uuid, topic, data);
  if(redisIoEmitter){
    redisIoEmitter.in(uuid).emit(topic, data);
  }else{
    io.sockets.in(uuid).emit(topic, data);
    ios.sockets.in(uuid).emit(topic, data);
  }
}

function mqttEmitter(uuid, wrappedData, options){
  if(mqttclient){
    mqttclient.publish(uuid, wrappedData, options);
  }
}

var sendMessage = sendMessageCreator(socketEmitter, mqttEmitter);

function emitToClient(topic, device, msg){
  if(device.protocol === "mqtt"){
    // MQTT handler
    console.log('sending mqtt', device);
    mqttEmitter(device.uuid, wrapMqttMessage(topic, msg), {qos:qos});
  }
  else{
    socketEmitter(device.uuid, topic, msg);
  }

}



// function forwardMessage(message, fn){
//   if(parentConnection){
//     try{
//       parentConnection.message(message, fn);
//     }catch(ex){
//       console.log('error forwarding message', ex);
//     }
//   }
// }


function sendActivity(data){
  //TODO throttle, maybe only send out with IP
  if(config.broadcastActivity){
    console.log("SENDING ACTIVITY DATA");
    data = data || {};
    var activityMessage = {};
    activityMessage.devices = "*";
    activityMessage.payload = data;
    sendMessage({uuid: config.uuid}, activityMessage);
  }

}

var skynet = {
  sendMessage: sendMessage,
  gateway : setupGatewayConfig(emitToClient),
  sendActivity: sendActivity,
  throttles: throttles,
  io: io,
  ios: ios,
  emitToClient: emitToClient
};

function checkConnection(socket, secure){
  //console.log(socket);
  // var ip = socket.handshake.address.address;
  var ip = socket.handshake.address;
  // var ip = socket.request.connection.remoteAddress
  // console.log(ip);

  if(_.contains(throttles.unthrottledIps, ip)){
    socketLogic(socket, secure, skynet);
  }else{
    throttles.connection.rateLimit(ip, function (err, limited) {
      if(limited){
        socket.emit('notReady',{error: 'rate limit exceeded ' + ip});
        socket.disconnect();
      }else{
        console.log('io connected');
        socketLogic(socket, secure, skynet);
      }
    });
  }

}



io.on('connection', function (socket) {
  checkConnection(socket, false);
  var client = socket.conn.request;
  console.log('CONNECTED', socket.handshake.address);
});

if(config.tls){
  ios.on('connection', function (socket) {
    checkConnection(socket, true);
  });
}


var qos = 0;

var mqttclient = setupMqttClient(skynet, config);


// Redirect www subdomain to root domain for https cert
// if(config.tls){
//   server.get(/^\/.*/, function(req, res, next) {
//     if (req.headers.host.match(/^www/) !== null) {
//       // return res.redirect("https://" + req.headers.host.replace(/www\./i, "") + req.url);
//       res.send(302, "https://" + req.headers.host.replace(/www\./i, "") + req.url);
//     } else {
//       return next;
//     }
//   });
// };

// Integrate coap
var coap       = require('coap'),
    coapRouter = require('./lib/coapRouter'),
    coapServer = coap.createServer(),
    coapConfig = config.coap || {};

setupCoapRoutes(coapRouter, skynet);

coapServer.on('request', coapRouter.process);


// Now, setup both servers in one step
setupRestfulRoutes(server, skynet);

if(config.tls){
  setupRestfulRoutes(https_server, skynet);
}







console.log("\nMM    MM              hh      bb      lll         ");
console.log("MMM  MMM   eee   sss  hh      bb      lll uu   uu ");
console.log("MM MM MM ee   e s     hhhhhh  bbbbbb  lll uu   uu ");
console.log("MM    MM eeeee   sss  hh   hh bb   bb lll uu   uu ");
console.log("MM    MM  eeeee     s hh   hh bbbbbb  lll  uuuu u ");
console.log("                 sss                              ");
console.log('\Meshblu (formerly skynet.im) %s environment loaded... ', app.environment);

// Start our restful servers to listen on the appropriate ports

var coapPort = coapConfig.port || 5683;
var coapHost = coapConfig.host || 'localhost';

// Passing in null for the host responds to any request on server
// coapServer.listen(coapPort, coapHost, function () {
// coapServer.listen(coapPort, null, function () {
coapServer.listen(coapPort, function () {
  console.log('CoAP listening at coap://' + coapHost + ':' + coapPort);
});

server.listen(process.env.PORT || config.port, function() {
  console.log('HTTP listening at %s', server.url);
});

if(config.tls){
  https_server.listen(process.env.SSLPORT || config.tls.sslPort, function() {
    console.log('HTTPS listening at %s', https_server.url);
  });
}
