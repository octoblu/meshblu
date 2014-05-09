var r192 = new RegExp(/^192\.168\./);
var r10 = new RegExp(/^10\./);

function sameLAN(fromIp, toIp){
  if(!toIp || !fromIp){
    return false;
  }

  if(toIp === fromIp){
    return true;
  }
  else if(r10.test(fromIp) && r10.test(toIp)){
    return true;
  }
  else if(r192.test(fromIp) && r192.test(toIp)){
    return true;
  }

  return false;

}

module.exports = {
  sameLAN : sameLAN
};
