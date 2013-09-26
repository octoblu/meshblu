var devices = require('./database').collection('devices');

module.exports = function(socket) {

  var newTimestamp = new Date().getTime();

  devices.update({
    uuid: socket.uuid
  }, {
    $set: {socketId: socket.socketid}
  }, function(err, saved) {
    console.log('socketid updated');
    return
  });

};