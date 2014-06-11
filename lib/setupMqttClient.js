var whoAmI = require('./whoAmI');
var logData = require('./logData');

function setMqttClient(skynet, mqttclient){

  // Handle MQTT Messages
  try{
     mqttclient.on('connect', function(){
      console.log('...connected via mqtt');
      mqttclient.subscribe('skynet');
      mqttclient.subscribe('update');
      mqttclient.subscribe('message');
      mqttclient.subscribe('data');
    });

    mqttclient.on('message', function (topic, message) {
      // console.log('mqtt message received', topic, message);
      console.log('mqtt message received:', topic);
      //console.log(message);
      try{
        message = JSON.parse(message);
        if(message.fromUuid){
          console.log('message', message);
          whoAmI(message.fromUuid, false, function(fromDevice){
            if(topic === 'message'){
              skynet.sendMessage(fromDevice, message);
            }
            else if(topic === 'data'){

              logData(message, function(results){
                console.log(results);

                // Send messsage regarding data update
                var broadcast = {
                  payload: message,
                  devices: '*'
                };

                console.log('message: ' + JSON.stringify(broadcast));

                skynet.sendMessage(fromDevice, broadcast);

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
