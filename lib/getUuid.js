module.exports = function(socket, callback) {
  if(socket.uuid){
    return callback(null, socket.uuid);
  }else{
    return callback(new Error('uuid not found for socket' + socket), null);
  }
};
