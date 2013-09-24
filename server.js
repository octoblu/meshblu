var config = require('./config');
var restify = require('restify');
var socketio = require('socket.io');

var server = restify.createServer();
var io = socketio.listen(server);

server.use(restify.acceptParser(server.acceptable));
server.use(restify.queryParser());
server.use(restify.bodyParser());

// curl -X GET http://localhost:3000/status
server.get('/status', require('./lib/getStatus'));

// server.get('/', function indexHTML(req, res, next) {
//     fs.readFile(__dirname + '/index.html', function (err, data) {
//         if (err) {
//             next(err);
//             return;
//         }

//         res.setHeader('Content-Type', 'text/html');
//         res.writeHead(200);
//         res.end(data);
//         next();
// });


io.sockets.on('connection', function (socket) {
    socket.emit('news', { hello: 'world' });
    socket.on('my other event', function (data) {
            console.log(data);
    });
});

// server.listen(8080, function () {
//     console.log('socket.io server listening at %s', server.url);
// });
server.listen(process.env.PORT || config.port, function() {
  console.log('%s listening at %s', server.name, server.url);
});