
module.exports = function(socket, callback) {
  console.log('getDevice socket info:', socket.id, socket.skynetDevice);

  if(socket.skynetDevice){
    return callback(null, socket.skynetDevice);
  }else{
    return callback(new Error('skynetDevice not found for socket' + socket), null);
  }

};
