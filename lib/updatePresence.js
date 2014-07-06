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
      console.log('Device not found for socket: ' + socket);
      return;
    } else {
      console.log('Device went offline: ' + socket);

      //disconnect any bound sockets asynchronously
      try{
        bindSocket.disconnect(socket);
      } catch(e){
        console.log(e);
      }

      return;
    }
  });

};
