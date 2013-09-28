var config = require('./config');
var restify = require('restify');
var socketio = require('socket.io');

var server = restify.createServer();
var io = socketio.listen(server);

server.use(restify.acceptParser(server.acceptable));
server.use(restify.queryParser());
server.use(restify.bodyParser());

io.sockets.on('connection', function (socket) {

  console.log('Websocket connection detected. Requesting identification from socket id: ' + socket.id.toString());
  
  socket.emit('identify', { socketid: socket.id.toString() });
  socket.on('identity', function (data) {
          console.log('Identity received: ' + JSON.stringify(data));
          require('./lib/updateSocketId')(data, function(auth){
            socket.emit('authentication', { status: auth.status });
          });
  });

  socket.on('disconnect', function (data) {
          console.log('Presence offline for socket id: ' + socket.id.toString());
          require('./lib/updatePresence')(socket.id.toString());
  });

});

// curl http://localhost:3000/status
server.get('/status', require('./lib/getSystemStatus'));

// curl http://localhost:3000/devices
// curl http://localhost:3000/devices?key=123
// curl http://localhost:3000/devices?online=true
server.get('/devices', require('./lib/getDevices'));

// curl http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
server.get('/devices/:uuid', require('./lib/whoami'));

// curl -X POST -d "name=arduino&description=this+is+a+test" http://localhost:3000/devices
server.post('/devices', require('./lib/register'));

// curl -d "token=123&online=true" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
server.put('/devices/:uuid', require('./lib/updateDevice'));

// curl -X DELETE -d "token=123" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
server.del('/devices/:uuid', require('./lib/unregister'));

// curl -X POST -d '{"blink":"start"}' http://localhost:3000/messages/ad698900-2546-11e3-87fb-c560cb0ca47b
// curl -X POST -d '{"blink":"stop"}' http://localhost:3000/messages/ad698900-2546-11e3-87fb-c560cb0ca47b
// curl -X POST -d '{"blink":"start"}' http://localhost:3000/messages/all
// curl -X POST -d '{"blink":"stop"}' http://localhost:3000/messages/all
server.post('/messages/:uuid', function(req, res, next){

  if(req.params.uuid = "all"){

      var body = req.body;
      console.log('message: ' + body);
      io.sockets.emit('message', JSON.parse(body));
      res.json({socketid: "all", body: JSON.parse(body)});

  } else {

    require('./lib/getSocketId')(req.params.uuid, function(data){
      var body = req.body;
      console.log('message: ' + body);
      io.sockets.socket(data).emit('message', JSON.parse(body));
      res.json({socketid: data, body: JSON.parse(body)});
    });

  }
});

server.listen(process.env.PORT || config.port, function() {
  console.log('%s listening at %s', server.name, server.url);
});