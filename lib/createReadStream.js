var Readable = require('stream').Readable;

function noop(){}

function createReadStream(){
  var rs = new Readable();

  rs._read = noop;

  rs.pushMsg = function(msg){
    if(typeof msg === 'object'){
      rs.push(JSON.stringify(msg) + ',\n');
    }else{
      rs.push(msg + ',\n');
    }
  };

  return rs;
}

module.exports = createReadStream;
