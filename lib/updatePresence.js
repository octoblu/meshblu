var bindSocket = require('./bindSocket');
var config = require('./../config');

var devices = require('./database').devices;

module.exports = function(socket) {
  devices.update({
    socketid: socket
  }, {
    $set: {online: false}
  }, function(err, saved) {
    if(err || saved === 0 || (saved && !saved.updatedExisting)) {
      return;
    } else {
      //disconnect any bound sockets asynchronously
      try{
        bindSocket.disconnect(socket);
      } catch(e){
        console.error(e);
      }

      return;
    }
  });

};
