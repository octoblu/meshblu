var config = require('./config');
var restify = require('restify');
var socketio = require('socket.io');

var server = restify.createServer();
var io = socketio.listen(server);

server.use(restify.acceptParser(server.acceptable));
server.use(restify.queryParser());
server.use(restify.bodyParser());

// curl http://localhost:3000/status
server.get('/status', require('./lib/getSystemStatus'));

// curl http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
server.get('/devices', require('./lib/getDevices'));

// curl http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
server.get('/devices/:uuid', require('./lib/whoami'));

// curl -X POST -d "name=arduino&description=this+is+a+test" http://localhost:3000/devices
server.post('/devices', require('./lib/register'));

// curl -d "online=true" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
server.put('/devices/:uuid', require('./lib/updateDevice'));

// curl -X DELETE http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
server.del('/devices/:uuid', require('./lib/unregister'));



io.sockets.on('connection', function (socket) {
    socket.emit('identify', { socketid: socket.id.toString() });
    socket.on('register', function (data) {
            console.log(data);
    });
});

// server.listen(8080, function () {
//     console.log('socket.io server listening at %s', server.url);
// });
server.listen(process.env.PORT || config.port, function() {
  console.log('%s listening at %s', server.name, server.url);
});