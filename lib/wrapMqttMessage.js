function wrapMqttMessage(topic, data){
  try{
    return JSON.stringify({topic: topic, data: data});
  }catch(ex){
    console.log('error wrapping mqtt message', ex);
  }
}

module.exports = wrapMqttMessage;
