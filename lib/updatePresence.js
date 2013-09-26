var devices = require('./database').collection('devices');

module.exports = function(socket) {

  var newTimestamp = new Date().getTime();

  devices.update({
    socketid: socket
  }, {
    $set: {online: false}
  }, function(err, saved) {
    console.log('device offline: ' + socket);
    return
  });

};