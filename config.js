module.exports = {
  mongo: {
    databaseUrl: process.env.MONGODB_URI || process.env.MONGOHQ_URL
  },
  port: parseInt(process.env.PORT) || 80,
  tls: {
    sslPort: parseInt(process.env.SSL_PORT) || 443,
    cert: process.env.SSL_CERT,
    key: process.env.SSL_KEY
  },
  uuid: process.env.UUID,
  token: process.env.TOKEN,
  broadcastActivity: (process.env.BROADCAST_ACTIVITY || "false").toLowerCase() == "true",
  log: (process.env.USE_LOG || "true").toLowerCase() == "true",
  elasticSearch: {
    host: process.env.ELASTIC_SEARCH_HOST,
    port: parseInt(process.env.ELASTIC_SEARCH_PORT)
  },
  splunk: {
    protocol: process.env.SPLUNK_PROTOCOL || "http", 	//This should be "http" OR "https"
    host: process.env.SPLUNK_HOST, 			//The Host to connect to
    port: parseInt(process.env.SPLUNK_PORT) || 8089, 	//The Splunk Port
    user: process.env.SPLUNK_USER,			//The user to connect with - does not have to be admin
    password: process.env.SPLUNK_PASSWORD,		//The Password
    index: process.env.SPLUNK_INDEX || "meshblu"	//The Splunk index to send the data to. OCT-TA-meshblu uses "meshblu"
  },
  rateLimits: {
    message: parseInt(process.env.RATE_LIMITS_MESSAGE || 10),
    data: parseInt(process.env.RATE_LIMITS_DATA || 10),
    connection: parseInt(process.env.RATE_LIMITS_CONNECTION || 2),
    query: parseInt(process.env.RATE_LIMITS_QUERY || 2),
    whoami: parseInt(process.env.RATE_LIMITS_WHOAMI || 10),
    unthrottledIps: (process.env.RATE_LIMITS_UNTHROTTLED_IPS || '').split(',')
  },
  urbanAirship: {
    key: process.env.URBAN_AIRSHIP_KEY,
    secret: process.env.URBAN_AIRSHIP_SECRET
  },
  plivo: {
    authId: process.env.PLIVO_AUTH_ID,
    authToken: process.env.PLIVO_AUTH_TOKEN
  },
  redis: {
    host: process.env.REDIS_HOST,
    port: parseInt(process.env.REDIS_PORT),
    password: process.env.REDIS_PASSWORD
  },
  coap: {
    port: parseInt(process.env.COAP_PORT),
    host: process.env.COAP_HOST
  },
  mqtt: {
    databaseUrl: process.env.MQTT_DATABASE_URI,
    port: parseInt(process.env.MQTT_PORT),
    skynetPass: process.env.MQTT_PASSWORD
  },
  yo: {
    token: process.env.YO_TOKEN
  },
  skynet_override_token: process.env.OVERRIDE_TOKEN,
  useProxyProtocol: (process.env.USE_PROXY_PROTOCOL || "false").toLowerCase() == "true"
//    ,
//  parentConnection: {
//    uuid: process.env.PARENT_CONNECTION_UUID,
//    token: process.env.PARENT_CONNECTION_TOKEN,
//    server: process.env.PARENT_CONNECTION_SERVER,
//    port: parseInt(process.env.PARENT_CONNECTION_PORT)
//  }
};
