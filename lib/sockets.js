module.exports = function(socket) {

  // io.sockets.on('connection', function (socket) {
    console.log('websocket connection detected');
    
    socket.emit('identify', { socketid: socket.id.toString() });
    socket.on('identity', function (data) {
            console.log(data);
            require('./updateSocketId')(data);
    });

    socket.on('disconnect', function (data) {
            console.log(data);
            require('./updatePresence')(socket.id.toString());
    });


  // });

}