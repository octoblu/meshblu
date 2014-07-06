var mqtt = require('mqtt');

function setupMqttClient(skynet, config){

  var client;

  // Handle MQTT Messages
  try{

    var mqttConfig = config.mqtt || {};
    var mqttsettings = {
      keepalive: 1000, // seconds
      protocolId: 'MQIsdp',
      protocolVersion: 3,
      //clientId: 'skynet',
      username: 'skynet',
      password: process.env.MQTT_PASS || mqttConfig.skynetPass
    };
    //console.log('attempting mqtt connection', mqttsettings);
    var mqttPort = process.env.MQTT_PORT || mqttConfig.port || 1833;
    var mqttHost = process.env.MQTT_HOST || mqttConfig.host || 'localhost';
    client = mqtt.createClient(mqttPort, mqttHost, mqttsettings);
  } catch(e){
    console.log('no mqtt server found');
  }

  return client;

}

module.exports = setupMqttClient;
