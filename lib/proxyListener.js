// Taken from https://github.com/daguej/node-proxywrap
function connectionListener(socket) {
    var options = {};
    var self = this, realEmit = socket.emit, history = [], protocolError = false;

    // override the socket's event emitter so we can process data (and discard the PROXY protocol header) before the underlying Server gets it
    socket.emit = function(event, data) {
      history.push(Array.prototype.slice.call(arguments));
      if (event == 'readable') {
        onReadable();
      }
    }

    function restore() {
      // restore normal socket functionality, and fire any events that were emitted while we had control of emit()
      socket.emit = realEmit;
      for (var i = 0; i < history.length; i++) {
        realEmit.apply(socket, history[i]);
        if (history[i][0] == 'end' && socket.onend) socket.onend();
      }
      history = null;
    }

    socket.on('readable', onReadable);

    var header = '', buf = new Buffer(0);
    function onReadable() {
      var chunk;
      while (null != (chunk = socket.read())) {
        buf = Buffer.concat([buf, chunk]);
        header += chunk.toString('ascii');

        // if the first 5 bytes aren't PROXY, something's not right.
        if (header.length >= 5 && header.substr(0, 5) != 'PROXY') {
          protocolError = true;
          if (options.strict) {
            return socket.destroy('PROXY protocol error');
          }
        }

        var crlf = header.indexOf('\r');
        if (crlf > 0 || protocolError) {
          socket.removeListener('readable', onReadable);
          header = header.substr(0, crlf);

          var hlen = header.length;
          header = header.split(' ');
  
          if (!protocolError) {
            Object.defineProperty(socket, 'remoteAddress', {
              enumerable: false,
              configurable: true,
              get: function() {
                return header[2];
              }
            });
            Object.defineProperty(socket, 'remotePort', {
              enumerable: false,
              configurable: true,
              get: function() {
                return parseInt(header[4], 10);
              }
            });
          }

          // unshifting will fire the readable event
          socket.emit = realEmit;
          socket.unshift(buf.slice(protocolError ? 0 : crlf+2));

          self.emit('proxiedConnection', socket);

          restore();

          if (socket.ondata) {
            var data = socket.read();
            if (data) socket.ondata(data, 0, data.length);
          }

          break;

        }
        else if (header.length > 107) return socket.destroy('PROXY protocol error'); // PROXY header too long
      }
    }
}

function resetListeners(socket) {
  var cl = socket.listeners('connection');
  socket.removeAllListeners('connection');
  socket.addListener('connection', connectionListener);

  // add the old connection listeners to a custom event, which we'll fire after processing the PROXY header
  for (var i = 0; i < cl.length; i++) {
    socket.addListener('proxiedConnection', cl[i]);
  }

}

module.exports = {
  connectionListener : connectionListener,
  resetListeners : resetListeners
}
