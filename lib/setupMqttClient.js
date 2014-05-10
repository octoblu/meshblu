

function setMqttClient(skynet, mqttclient){

  // Handle MQTT Messages
  try{
    mqttclient.subscribe('skynet');
    // mqttclient.publish('742401f1-87a4-11e3-834d-670dadc0ddbf', 'Hello mqtt');

    mqttclient.on('message', function (topic, message) {
      // console.log('mqtt message received', topic, message);
      console.log('mqtt message received:', topic);
      console.log(message);
      try{
        message = JSON.parse(message);
      }catch(ex){
        console.log('exception parsing json', ex);
        return;
      }

      // require('./lib/authDevice')(message.uuid, message.token, function(auth){

      //   if (auth.authenticate == true){
      //     //TODO figure out how to rate limit without checking auth
      //     throttle.rateLimit(socket.id.toString(), function (err, limited) {
      //       var messageX = message;
      //       if (limited) {
      //         // TODO: Emit rate limit exceeded message
      //         console.log("Rate limit exceeded for mqtt:", messageX.uuid);
      //         console.log("message", messageX);

      //       } else {
      //         sendMessage(message.uuid, messageX);
      //       }
      //     });

      //   }else{
      //     console.log('invalid attempted mqtt publish', message);
      //   }

      //   var eventData = {devices: topic, message: message};
      //   logEvent(300, eventData);
      // });

      //add auth and throttling later

      // Determine is socket is secure
      // require('./lib/whoAmI')(message.uuid, false, function(check){
        // if(check.secure){
          // sendMessage(message.fromUuid, message, true);
        // } else {
          whoAmI(message.fromUuid, function(err, fromDevice){
            if(fromDevice){
              skynet.sendMessage(message.fromUuid, message);
            }
          });

        // }
      // });


    });
  } catch(e){
    console.log('no mqtt server found');
  }

}
