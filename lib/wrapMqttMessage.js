function wrapMqttMessage(topic, data){
  try{
    if(topic === 'tb'){
      if(typeof data !== 'string'){
        return JSON.stringify(data);
      }
      return data;
    }else{
      return JSON.stringify({topic: topic, data: data});
    }
  }catch(ex){
    console.error(ex);
  }
}

module.exports = wrapMqttMessage;
