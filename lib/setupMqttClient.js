var whoAmI = require('./whoAmI');
var logData = require('./logData');

function setMqttClient(skynet, mqttclient){

  // Handle MQTT Messages
  try{
     mqttclient.on('connect', function(){
      console.log('...connected via mqtt');
      mqttclient.subscribe('skynet');
    });

    mqttclient.on('message', function (topic, message) {
      // console.log('mqtt message received', topic, message);
      console.log('mqtt message received:', topic);
      //console.log(message);
      try{
        message = JSON.parse(message);
        if(message.data && message.fromUuid){
          console.log('message', message);
          whoAmI(message.fromUuid, false, function(fromDevice){
            if(message.topic === 'message'){
              skynet.sendMessage(fromDevice, message.data);
            }
            else if(message.topic === 'data'){

              logData(message.data, function(results){
                console.log(results);

                // Send messsage regarding data update
                var message = {
                  payload: message.data,
                  devices: '*'
                };

                console.log('message: ' + JSON.stringify(message));

                skynet.sendMessage(fromDevice, message);

              });
            }
          });

        }


      }catch(ex){
        console.log('exception parsing json', ex);
        return;
      }

    });
  } catch(e){
    console.log('no mqtt server found');
  }

}

module.exports = setMqttClient;
