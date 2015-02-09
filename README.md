# meshblu

[![Build Status](https://travis-ci.org/octoblu/meshblu.svg?branch=master)](https://travis-ci.org/octoblu/meshblu)
[![Code Climate](https://codeclimate.com/github/octoblu/meshblu/badges/gpa.svg)](https://codeclimate.com/github/octoblu/meshblu)
[![Test Coverage](https://codeclimate.com/github/octoblu/meshblu/badges/coverage.svg)](https://codeclimate.com/github/octoblu/meshblu)
[![Gitter chat](https://badges.gitter.im/gitterHQ/gitter.png)](https://gitter.im/octoblu/meshblu)

OPEN HTTP, WebSocket, MQTT, & CoAP COMMUNICATIONS NETWORK & API FOR THE INTERNET OF THINGS (IoT)!

Visit [developer.octoblu.com](http://developer.octoblu.com) for up-to-the-latest documentation and screencasts.

======

Introduction
------------

Meshblu is an open source machine-to-machine instant messaging network and API. Our API is available on HTTP REST, realtime Web Sockets via RPC (remote procedure calls), [MQTT](http://mqtt.org), and [CoAP](http://en.wikipedia.org/wiki/Constrained_Application_Protocol).  We seamlessly bridge all of these protocols. For instance, an MQTT device can communicate with any CoAP or HTTP or WebSocket connected device on Meshblu.

Meshblu auto-assigns 36 character UUIDs and secret tokens to each registered device connected to the network. These device "credentials" are used to authenticate with Meshblu and maintain your device's JSON description in the device directory.

Meshblu allows you to discover/query devices such as drones, hue light bulbs, weemos, insteons, raspberry pis, arduinos, server nodes, etc. that meet your criteria and send IM messages to 1 or all devices.

You can also subscribe to messages being sent to/from devices and their sensor activities.

Meshblu offers a Node.JS NPM module called [Meshblu](https://www.npmjs.org/package/meshblu) and a [meshblu.js](http://meshblu.octoblu.com/#javascript) file for simplifying Node.JS and mobile/client-side connectivity to Meshblu.


Press
-----
[AllSeen Alliance](https://allseenalliance.org/announcement/allseen-alliance-reaches-50-members-expands-smart-home-connected-car-and-security-focus) - Allseen Alliance reaches 50 members; expands smart home, connected car and security focus

[Sys-Con](http://iot.sys-con.com/node/3125944) - Exclusive Octoblu Interview @ThingsExpo Silicon Valley

[Onalytica](http://www.onalytica.com/blog/posts/the-internet-of-things-top-100-organizations) - The Internet of Things - Top 100 Organizations

[GigaOm](http://gigaom.com/2014/07/21/octoblu-launches-to-make-skynet-internet-of-things-tools-professional-grade/) - Octoblu launches to make Skynet internet of things tools professional grade

[VentureBeat](http://venturebeat.com/2014/07/22/internet-of-things-startup-octoblu-designs-a-platform-that-translates-protocols/) - Internet of things startup Octoblu designs a platform that translates protocols

[Forbes](http://www.forbes.com/sites/benkepes/2014/07/22/octoblu-rolls-out-its-internet-of-things-thing/) - Octoblu Peels Back The Covers On Its Internet Of Things Platform

[GigaOm](http://gigaom.com/2014/02/04/podcast-meet-skynet-an-open-source-im-platform-for-the-internet-of-things/) - Listen to Stacey Higginbotham from GigaOm interview Chris Matthieu, the founder of SkyNet, about our capabilities, uses, and future direction.

[Wired](http://www.wired.com/wiredenterprise/2014/02/skynet/) - ‘Yes, I’m trying to build SkyNet from Terminator.’

[Wired](http://www.wired.com/2014/05/iot-report/) - Why Tech’s Best Minds Are Very Worried About the Internet of Things

[LeapMotion](https://labs.leapmotion.com/46/) - Developer newsletter covers flying drones connected to SkyNet with LeapMotion sensor!

[The New Stack](http://thenewstack.io/a-messaging-network-for-drones-called-skynet/) - Drones Get A Messaging Network Aptly Called SkyNet

Roadmap
-------

* Phase 1 - Build a network and realtime API for enabling machine-to-machine communications.
* Phase 2 - Connect all of the thingz.
* Phase 3 - Become self-aware!

Installing/Running Meshblu private cloud
----------

Clone the git repository, then:

```bash
$ npm install
```

[Meshblu](http://meshblu.octoblu.com) uses Mongo, Redis, ElasticSearch, and Splunk; however, we have made this infrastructure optional for you.  Meshblu falls back to file system and memory storage if these services are not configured allowing you to deploy a private Meshblu cloud to a Raspberry Pi or other mini-computer!

If you want to include these services for a scalable infrastructure, you can make the following changes to your `config.js` file.

Modify `config.js` with your MongoDB connection string. If you have MongoDB running locally use:

```
mongo: {
  databaseUrl: mongodb://localhost:27017/skynet
},
```

You can also modify `config.js` with your Redis connection information. If you have Redis running locally use:

```
redis: {
  host: "127.0.0.1",
  port: "6379",
  password: "abcdef"
},
```

You can also modify `config.js` with your ElasticSearch connection information. If you have ES running locally use:

```
elasticSearch: {
  host: "localhost",
  port: "9200"
},
```

If you would like to connect your private Meshblu cloud to [meshblu.octoblu.com](http://meshblu.octoblu.com) or another private Meshblu cloud, register a UUID on the parent cloud (i.e. meshblu.octoblu.com) using the POST /Devices REST API and then add the returned UUID and token to the following section to your private cloud's config.js file:

```
parentConnection: {
  uuid: 'xxxx-my-uuid-on-parent-server-xxxx',
  token: 'xxx ---  my token ---- xxxx',
  server: 'meshblu.octoblu.com',
  port: 80
},
```

Start the Meshblu server running HTTP and WebSocket protocols use:

```bash
$ node server.js --http
```

You may also run something like [forever](https://www.npmjs.org/package/forever) to keep it up and running:

```bash
$ forever start server.js --http
```

MQTT Broker
-----------

MQTT is an optional Meshblu protocol.  If you would like to run our MQTT broker with your private Meshblu cloud, open another console tab and run:

```bash
$ node server.js --http --mqtt
```

 or using forever

 ```bash
 $ forever start server.js --http --mqtt
 ```

Note: Our MQTT Broker defaults to using Mongo; however, you can run it in memory by removing the databaseUrl from the config.js.

```
mqtt: {
  port: 1883,
  skynetPass: "Very big random password 34lkj23orfjvi3-94ufpvuha4wuef-a09v4ji0rhgouj"
}
```

CoAP
----

CoAP is an optional Meshblu protocol.  If you would like to run our CoAP protocol with your private Meshblu cloud, open another console tab and run:

```bash
$ node server.js --http --coap
```

 or using forever

 ```bash
 $ forever start server.js --http --coap
 ```

Note: Our CoAP protocol defaults to using Mongo; however, you can run it in memory by removing the databaseUrl from the config.js.

```
coap: {
  port: 5683,
  host: "localhost"
}
```

Heroku
------

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy)

Use the button above to deploy to the [Heroku](http://heroku.com/) cloud for Free! Starts out with a basic implementation of Meshblu with only MongoDB. The app.json / config.js can be modified to allow for more protocols and storage systems.

[Heroku](http://heroku.com/) allows you scale with a touch of a button.


DigitalOcean
------------

[![Install on DigitalOcean](http://installer.71m.us/button.svg)](http://installer.71m.us/install?url=https://github.com/octoblu/meshblu)

Use the button above to deploy to the [DigitalOcean](https://www.digitalocean.com/) cloud for as little as $5/month! The app.json / config.js can be modified to allow for more protocols and storage systems.


Docker
------

The default Dockerfile will run Meshblu, MongoDB and Redis in a single container to make quick experiments easier.

You'll need docker installed, then to build the Meshblu image:

From the directory where the Dockerfile resides run.

```
$ docker build -t=skynet .
```

To run a fully self contained instance using the source bundled in the container.

```
$ docker run -i -t -p 3000 skynet
```

This will run Meshblu (formerly skynet) and expose port 3000 from the container on a random host port that you can find by running docker ps.

If you want to do development and run without rebuilding the image you can bind mount your source directory including node_modules onto the container. This example also binds a directory to hold the log of stdout & stderr from the Meshblu node process.

```
$ docker run -d -p 3000 --name=skynet_dev -v /path/to/your/skynet:/var/www -v /path/to/your/logs:/var/log/skynet skynet
```

If you change the code restarting the container is as easy as:

```
$ docker restart skynet_dev
```

Nodeblu Developer Toolkit
--------------------------------
Play with [Meshblu](http://meshblu.octoblu.com) IoT platform in Chrome! [Nodeblu](https://chrome.google.com/webstore/detail/nodeblu/aanmmiaepnlibdlobmbhmfemjioahilm) helps you experiment with the [Octoblu](http://octoblu.com) and [Meshblu](http://meshblu.octoblu.com) Internet of Things platforms by dragging, dropping, and wiring up various nodes connected to Meshblu!

Nodeblu is Octoblu's fork of the popular [NodeRED](https://github.com/node-red/node-red) application from IBM.  Since our app is deployed as a Chrome extension, we decided to add extra local features such as speech recognition and text-to-speech, a WebRTC webcam, HTML5 notifications, access to ChromeDB, a gamepad controller, and access to local and remote Arduino and Spark devices via our [Microblu](https://github.com/octoblu/microblu_mqtt) OS.

<p align="center">
  <a href="https://chrome.google.com/webstore/detail/nodeblu/aanmmiaepnlibdlobmbhmfemjioahilm">
    <img width="100%" src="https://pbs.twimg.com/media/BqXMR8ECAAEvzFf.png"/>
  </a>
</p>

Gateblu
-------

We have an open source Octoblu Gateway also available on [GitHub](https://github.com/octoblu/gateblu). Our Gateway allows you to connect devices with or *without* IP addresses to Meshblu and communicate bi-directionally!  The Gateway uses WebSockets to connect to Meshblu so it can traverse NAT firewalls and send/receive messages to/from Meshblu.

Gateblu has an extensible [plugin](https://github.com/octoblu/gateblu/blob/master/plugins.md) architecture allowing you to create plugins for devices that we have not had a chance to connect yet.  You can search [NPMJS.org](https://www.npmjs.org/search?q=skynet-plugin) for a list of active Gateblu plugins.

Microblu Operating System
-----------------------

Meshblu includes a micro-controller operating system that is compatible with [Arduino](http://www.arduino.cc/), [Spark](https://www.spark.io/), and [Pinoccio](https://pinocc.io/)!  The OS is available on [GitHub](https://github.com/octoblu/microblu_mqtt) and comes with firmata built-in.

On power-on, the Microblu OS connects to Meshblu, obtains a UUID, and awaits your instructions! You can message the micro-controller to turn on/off pins and servos as well as request streaming analog sensor data from various pins.

HTTP(S) REST API
----------------

Most of our API endpoints require authentication credentials (UUID and secret token) passed in the HTTP headers as meshblu_auth_uuid and meshblu_auth_token respectively. These credentials are generated by registering a device or user with Meshblu via the POST /Devices API (see below). If you would like to associate additional Meshblu devices with the UUID and Token that you created (as a user), you can add an "owner" property to your other devices with the user's UUID as its value; otherwise, you can use the device's UUID and token in the headers to control the device itself.

We support the following device permissions: Discover, Send Messages, Receive Messages (subscribe) and Configure (Update). These permissions are manageable by adding UUIDs to whitelists and blacklists arrays with the following names: discoverWhitelist, discoverBlacklist, sendWhitelist, sendBlacklist, receiveWhitelist, receiveBlacklist, updateWhitelist, updateBlacklist. Note: If your UUID is the same as the "owner" UUID, these permissions are not enforced (you are the owner).

GET /status

Returns the current status of the Meshblu network

```
curl http://localhost:3000/status

=> {"skynet":"online","timestamp":1380480777750,"eventCode":200}
```

GET /devices

Returns an array of all devices available to you on Meshblu. Notice you can query against custom properties i.e. all drones or light switches and online/offline etc.

```
curl "http://localhost:3000/devices" --header "meshblu_auth_uuid: {my uuid}" --header "meshblu_auth_token: {my token}"

curl "http://localhost:3000/devices?key=123" --header "meshblu_auth_uuid: {my uuid}" --header "meshblu_auth_token: {my token}"

curl "http://localhost:3000/devices?online=true" --header "meshblu_auth_uuid: {my uuid}" --header "meshblu_auth_token: {my token}"

curl "http://localhost:3000/devices?key=123&online=true" --header "meshblu_auth_uuid: {my uuid}" --header "meshblu_auth_token: {my token}"

=> ["ad698900-2546-11e3-87fb-c560cb0ca47b","2f3113d0-2796-11e3-95ef-e3081976e170","9c62a150-29f6-11e3-89e7-c741cd5bd6dd","f828ef20-29f7-11e3-9604-b360d462c699","d896f9f0-29fb-11e3-a27c-614201ddde6e"]
```

GET /devices/uuid

Returns all information on a given device by its UUID

```
curl "http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26" --header "meshblu_auth_uuid: {my uuid}" --header "meshblu_auth_token: {my token}"

=> {"_id":"5241d9140345450000000001","channel":"main","deviceDescription":"this is a test","deviceName":"hackboard","key":"123","online":true,"socketid":"pG5UAhaZa_xXlvrItvTd","timestamp":1380340661522,"uuid":"ad698900-2546-11e3-87fb-c560cb0ca47b"}b
```

POST /devices

Registers a device on the Meshblu network. You can add as many properties to the device object as desired. Meshblu returns a device UUID and token which needs to be used with future updates to the device object

Note: You can pass in a token parameter to overide skynet issuing you one

```
curl -X POST -d "name=arduino&description=this+is+a+test" "http://localhost:3000/devices" --header "meshblu_auth_uuid: {my uuid}" --header "meshblu_auth_token: {my token}"

curl -X POST -d "name=arduino&token=123" "http://localhost:3000/devices" --header "meshblu_auth_uuid: {my uuid}" --header "meshblu_auth_token: {my token}"

=> {"name":"arduino","description":"this is a test","uuid":"8220cff0-2939-11e3-88cd-0b8e5fdfd7d4","timestamp":1380481272431,"token":"1yw0nfc54okcsor2tfqqsuvnrcf2yb9","online":false,"_id":"524878f8cc12f0877f000003"}
```

PUT /devices/uuid

Updates a device object. Token is required for security.

```
curl -X PUT -d "token=123&online=true" "http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26" --header "meshblu_auth_uuid: {my uuid}" --header "meshblu_auth_token: {my token}"

=> {"uuid":"8220cff0-2939-11e3-88cd-0b8e5fdfd7d4","timestamp":1380481439002,"online":true}
```

DELETE /devices/uuid

Unregisters a device on the Meshblu network. Token is required for security.

```
curl -X DELETE -d "token=123" "http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26" --header "meshblu_auth_uuid: {my uuid}" --header "meshblu_auth_token: {my token}"

=> {"uuid":"8220cff0-2939-11e3-88cd-0b8e5fdfd7d4","timestamp":1380481567799}
```

GET /localdevices

Returns a list of unclaimed devices that are on the same network as the requesting resource.

```
curl -X GET http://meshblu.octoblu.com/localdevices --header "meshblu_auth_uuid: {my uuid}" --header "meshblu_auth_token: {my token}"

=> {"devices":[{"autoRegister":true,"online":false,"timestamp":"2014-08-05T20:38:31.139Z","ipAddress":"184.98.43.115","protocol":"websocket","secure":false,"uuid":"76537331-1ce0-11e4-861d-89322229e557","channel":"main"},{"autoRegister":true,"online":true,"timestamp":"2014-08-05T16:50:52.492Z","ipAddress":"184.98.43.115","protocol":"websocket","secure":false,"uuid":"a92350c1-1cc0-11e4-861d-89322229e557","channel":"main"}]}
```

GET /claimdevice/:uuid

Adds the meshblu_auth_uuid as the owner of this device UUID allowing a user or device to claim ownership of another device.

```
curl -X PUT http://meshblu.octoblu.com/claimdevice/{:uuid} --header "meshblu_auth_uuid: {my uuid}" --header "meshblu_auth_token: {my token}"

=> {"updatedExisting":true,"n":1,"connectionId":232,"err":null,"ok":1}
```

GET /mydevices

Returns all information (including tokens) of all devices or nodes belonging to a user's UUID (identified as "owner")

```
curl -X GET "http://meshblu.octoblu.com/mydevices" --header "meshblu_auth_uuid: {my uuid}" --header "meshblu_auth_token: {my token}"

=> {"devices":[{"owner":"0d1234a0-1234-11e3-b09c-1234e847b2cc","name":"SMS","phoneNumber":"16025551234","uuid":"1c1234e1-xxxx-11e3-1234-671234c01234","timestamp":1390861609070,"token":"1234eg1234zz1tt1234w0op12346bt9","channel":"main","online":false,"_id":"52e6d1234980420c4a0001db"}}]}
```

POST /messages

Sends a JSON message to all devices or an array of devices or a specific device on the Meshblu network.

```
curl -X POST -d '{"devices": "all", "message": {"yellow":"off"}}' "http://localhost:3000/messages" --header "meshblu_auth_uuid: {my uuid}" --header "meshblu_auth_token: {my token}"

curl -X POST -d '{"devices": ["ad698900-2546-11e3-87fb-c560cb0ca47b","2f3113d0-2796-11e3-95ef-e3081976e170"], "message": {"yellow":"off"}}' "http://localhost:3000/messages" --header "meshblu_auth_uuid: {my uuid}" --header "meshblu_auth_token: {my token}"

curl -X POST -d '{"devices": "ad698900-2546-11e3-87fb-c560cb0ca47b", "message": {"yellow":"off"}}' "http://localhost:3000/messages" --header "meshblu_auth_uuid: {my uuid}" --header "meshblu_auth_token: {my token}"

=> {"devices":"ad698900-2546-11e3-87fb-c560cb0ca47b","message":{"yellow":"off"},"timestamp":1380930482043,"eventCode":300}
```

Note: If your Meshblu cloud is connected to meshblu.octoblu.com or other private Meshblu clouds, you can send messages across Meshblu clouds by chaining UUIDs together separated by slashes (/) where the first UUID is the target cloud and the second UUID is the device on that cloud.

```
curl -X POST -d '{"devices": "ad698900-2546-11e3-87fb-c560cb0ca47b/2f3113d0-2796-11e3-95ef-e3081976e170", "message": {"yellow":"off"}}' "http://localhost:3000/messages" --header "meshblu_auth_uuid: {my uuid}" --header "meshblu_auth_token: {my token}"
```

GET /events/uuid?token=token

Returns last 10 events related to a specific device or node

```
curl -X GET "http://meshblu.octoblu.com/events/ad698900-2546-11e3-87fb-c560cb0ca47b?token=123" --header "meshblu_auth_uuid: {my uuid}" --header "meshblu_auth_token: {my token}"

=> {"events":[{"uuid":"0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc","socketid":"lnHHS06ijWUXEzb01ZRy","timestamp":1382632438785,"eventCode":101,"_id":"52694bf6ad11379eec00003f"},{"uuid":"0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc","socketid":"BuwnWQ_oLmpk5R3m1ZRv","timestamp":1382561240563,"eventCode":101,"_id":"526835d8ad11379eec000017"}]}
```

GET /subscribe

This is a streaming API that returns device/node mesages as they are sent and received. Notice the comma at the end of the response. Meshblu doesn't close the stream.

```
curl -X GET "http://meshblu.octoblu.com/subscribe" --header "meshblu_auth_uuid: {my uuid}" --header "meshblu_auth_token: {my token}"

=> [{"devices":"0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc","message":{"red":"on"},"timestamp":1388768270795,"eventCode":300,"_id":"52c6ec0e4f67671e44000001"},{"devices":"0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc","message":{"red":"on"},"timestamp":1388768277473,"eventCode":300,"_id":"52c6ec154f67671e44000002"},
```

GET /subscribe/uuid

This is a streaming API that returns device/node broadcast mesages as they are sent. Notice the comma at the end of the response. Meshblu doesn't close the stream.

```
curl -X GET "http://meshblu.octoblu.com/subscribe/ad698900-2546-11e3-87fb-c560cb0ca47b" --header "meshblu_auth_uuid: {my uuid}" --header "meshblu_auth_token: {my token}"

=> [{"fromUuid":"ad698900-2546-11e3-87fb-c560cb0ca47b","devices":"*",message":{"red":"on"},"timestamp":1388768270795,"eventCode":300,"_id":"52c6ec0e4f67671e44000001"},{"fromUuid":"ad698900-2546-11e3-87fb-c560cb0ca47b","devices":"*",,"message":{"red":"on"},"timestamp":1388768277473,"eventCode":300,"_id":"52c6ec154f67671e44000002"},
```

GET /authenticate/uuid?token=token

Returns UUID and authticate: true or false based on the validity of uuid/token credentials

```
curl -X GET "http://meshblu.octoblu.com/authenticate/81246e80-29fd-11e3-9468-e5f892df566b?token=5ypy4rurayktke29ypbi30kcw5ovfgvi" --header "meshblu_auth_uuid: {my uuid}" --header "meshblu_auth_token: {my token}"

=> {"uuid":"81246e80-29fd-11e3-9468-e5f892df566b","authentication":true} OR {"uuid":"81246e80-29fd-11e3-9468-e5f892df566b","authentication":false}
```

GET /ipaddress

Returns the public IP address of the request. This is useful when working with the Octoblu Gateway behind a firewall.

```
curl -X GET http://meshblu.octoblu.com/ipaddress

=> {"ipAddress":"70.171.149.205"}
```

POST /data/uuid

Stores your device's sensor data to Meshblu

```
curl -X POST -d "token=123&temperature=78" "http://meshblu.octoblu.com/data/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc" --header "meshblu_auth_uuid: {my uuid}" --header "meshblu_auth_token: {my token}"

=> {"timestamp":"2014-03-25T16:38:48.148Z","uuid":"0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc","temperature":"30","ipAddress":"127.0.0.1","eventCode":700,"_id":"5331b118512c974805000002"}
```

GET /data/uuid

Retrieves your device's sensor data to Meshblu

```
curl -X GET "http://localhost:3000/data/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc?token=123" --header "meshblu_auth_uuid: {my uuid}" --header "meshblu_auth_token: {my token}"

=> {"data":[{"timestamp":"2014-03-25T16:38:48.148Z","uuid":"0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc","temperature":"30","ipAddress":"127.0.0.1","id":"5331b118512c974805000001"},{"timestamp":"2014-03-23T18:57:16.093Z","uuid":"0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc","temperature":"78","ipAddress":"127.0.0.1","id":"532f2e8c9c23809e93000001"}]}
```

CoAP API
--------

Our CoAP API works exactly like our REST API.  You can use [Matteo Collina's](https://twitter.com/matteocollina) [CoAP CLI](https://www.npmjs.org/package/coap-cli) for testing CoAP REST API calls.  Here are a few examples:

coap get coap://coap.octoblu.com/status

coap get -H "meshblu_auth_uuid={:UUID}&meshblu_auth_token={:TOKEN}" coap://coap.octoblu.com/devices?type=drone

coap get -H "meshblu_auth_uuid={:UUID}&meshblu_auth_token={:TOKEN}" coap://coap.octoblu.com/devices/ad698900-2546-11e3-87fb-c560cb0ca47b

coap post -p "type=drone&color=black" -H "meshblu_auth_uuid={:UUID}&meshblu_auth_token={:TOKEN}" coap://coap.octoblu.com/devices

coap put -p "token=123&color=blue&online=true" -H "meshblu_auth_uuid={:UUID}&meshblu_auth_token={:TOKEN}" coap://coap.octoblu.com/devices/ad698900-2546-11e3-87fb-c560cb0ca47b

coap delete -p "token=123" -H "meshblu_auth_uuid={:UUID}&meshblu_auth_token={:TOKEN}" coap://coap.octoblu.com/devices/ad698900-2546-11e3-87fb-c560cb0ca47b

coap get -H "meshblu_auth_uuid={:UUID}&meshblu_auth_token={:TOKEN}" coap://coap.octoblu.com/mydevices/0d1234a0-1234-11e3-b09c-1234e847b2cc?token=1234glm6y1234ldix1234nux41234sor

coap post -p '{"devices": "*", "payload": {"yellow":"off"}}' -H "meshblu_auth_uuid={:UUID}&meshblu_auth_token={:TOKEN}" coap://coap.octoblu.com/messages

coap get -H "meshblu_auth_uuid={:UUID}&meshblu_auth_token={:TOKEN}" coap://coap.octoblu.com/events/ad698900-2546-11e3-87fb-c560cb0ca47b?token=123

coap get -H "meshblu_auth_uuid={:UUID}&meshblu_auth_token={:TOKEN}" coap://coap.octoblu.com/subscribe -o

coap get -H "meshblu_auth_uuid={:UUID}&meshblu_auth_token={:TOKEN}" coap://coap.octoblu.com/subscribe/ad698900-2546-11e3-87fb-c560cb0ca47b -o

coap get -H "meshblu_auth_uuid={:UUID}&meshblu_auth_token={:TOKEN}" coap://coap.octoblu.com/ipaddress

coap post -p "token=123&temperature=78" -H "meshblu_auth_uuid={:UUID}&meshblu_auth_token={:TOKEN}" coap://coap.octoblu.com/data/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc

coap get -H "meshblu_auth_uuid={:UUID}&meshblu_auth_token={:TOKEN}" coap://coap.octoblu.com/data/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc?token=123


WEBSOCKET API
-------------

Request and receive system status

```js
socket.emit('status', function (data) {
  console.log(data);
});
```

Request and receive an array of devices matching a specific criteria

```js
socket.emit('devices', {"key":"123"}, function (data) {
  console.log(data);
});
```

Request and receive information about a specific device

```js
socket.emit('whoami', {"uuid":"ad698900-2546-11e3-87fb-c560cb0ca47b"}, function (data) {
  console.log(data);
});
```

Request and receive a device registration

```js
socket.emit('register', {"key":"123"}, function (data) {
  console.log(data);
});
```

Request and receive a device update

```js
socket.emit('update', {"uuid":"ad698900-2546-11e3-87fb-c560cb0ca47b", "token": "zh4p7as90pt1q0k98fzvwmc9rmjkyb9", "key":"777"}, function (data) {
  console.log(data);
});
```

Request and receive a device unregistration

```js
socket.emit('unregister', {"uuid":"b5535950-29fd-11e3-9113-0bd381f0b5ef", "token": "2ls40jx80s9bpgb9w2g0vi2li72v5cdi"}, function (data) {
  console.log(data);
});
```

Store sensor data for a device uuid

```js
socket.emit('data', {"uuid":"b5535950-29fd-11e3-9113-0bd381f0b5ef", "token": "2ls40jx80s9bpgb9w2g0vi2li72v5cdi", "temperature": 55}, function (data) {
  console.log(data);
});

```

Request and receive an array of sensor data matching a specific criteria

```js
socket.emit('getdata', {"uuid":"b5535950-29fd-11e3-9113-0bd381f0b5ef", "token": "2ls40jx80s9bpgb9w2g0vi2li72v5cdi", "limit": 1}, function (data) {
  console.log(data);
});
```


Request and receive a message broadcast

```js
// sending message to all devices
socket.emit('message', {"devices": "all", "message": {"yellow":"on"}});

// sending message to a specific devices
socket.emit('message', {"devices": "b5535950-29fd-11e3-9113-0bd381f0b5ef", "message": {"yellow":"on"}});

// sending message to an array of devices
socket.emit('message', {"devices": ["b5535950-29fd-11e3-9113-0bd381f0b5ef", "ad698900-2546-11e3-87fb-c560cb0ca47b"], "message": {"yellow":"on"}});
```

Websocket API commands include: status, register, unregister, update, whoami, devices, subscribe, unsubscribe, authenticate, and message. You can send a message to a specific UUID or an array of UUIDs or all nodes on SkyNet.

MQTT API
--------

Our MQTT API works similar to our WebSocket API. In fact, we have a [skynet-mqtt](https://www.npmjs.org/package/skynet-mqtt) NPM module for to simplify client-side MQTT connects with SkyNet.

```bash
$ npm install skynet-mqtt
```

Here are a few examples:


```javascript
var skynet = require('skynet-mqtt');

var conn = skynet.createConnection({
  "uuid": "xxxxxxxxxxxx-My-UUID-xxxxxxxxxxxxxx",
  "token": "xxxxxxx-My-Token-xxxxxxxxx",
  "qos": 0, // MQTT Quality of Service (0=no confirmation, 1=confirmation, 2=N/A)
  "host": "localhost", // optional - defaults to meshblu.octoblu.com
  "port": 1883  // optional - defaults to 1883
});

conn.on('ready', function(){

  console.log('UUID AUTHENTICATED!');

  //Listen for messages
  conn.on('message', function(message){
    console.log('message received', message);
  });


  // Send a message to another device
  conn.message({
    "devices": "xxxxxxx-some-other-uuid-xxxxxxxxx",
    "payload": {
      "skynet":"online"
    }
  });


  // Broadcast a message to any subscribers to your uuid
  conn.message({
    "devices": "*",
    "payload": {
      "hello":"skynet"
    }
  });


  // Subscribe to broadcasts from another device
  conn.subscribe('xxxxxxx-some-other-uuid-xxxxxxxxx');


  // Log sensor data to skynet
  conn.data({temperature: 75, windspeed: 10});

});

```

Event Codes
-----------

If `log: true` in config.js, all transactions are logged to skynet.txt.  Here are the event codes associated with Meshblu transactions.

* 100 = Web socket connected
* 101 = Web socket identification
* 102 = Authenticate
* 200 = System status API call
* 201 = Get events
* 204 = Subscribe
* 205 = Unsubscribe
* 300 = Incoming message
* 301 = Incoming SMS message
* 302 = Outgoing SMS message
* 303 = Incoming Yo message
* 304 = Outgoing Yo message
* 305 = Outgoing Push Notification message
* 400 = Register device
* 401 = Update device
* 402 = Delete device
* 403 = Query devices
* 500 = WhoAmI
* 600 = Gateway Config API call
* 700 = Write sensor data
* 701 = Read sensor data

FOLLOW US!
----------

* [Twitter/Octoblu](http://twitter.com/octoblu)
* [Facebook/Octoblu](http://facebook.com/octoblu)
* [Google Plus](https://plus.google.com/communities/106179367424841209509)


LICENSE
-------

(MIT License)

Copyright (c) 2014 Octoblu <info@octoblu.com>

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
