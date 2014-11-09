
function getActivity(topic, ip, device, toDevice, messageData){
  var data = {ipAddress: ip};
  if(topic){
    data.topic = topic;
  }
  if(device && device.type){
    data.type = device.type;
  }
  if(toDevice && toDevice.ipAddress){
    data.toIpAddress = toDevice.ipAddress;
  }
  if(toDevice && toDevice.type){
    data.toType = toDevice.type;
  }
  if(messageData){
    data.message = messageData;
  }
  return data;
}

module.exports = getActivity;
