```
 SSSSS  kk                            tt
SS      kk  kk yy   yy nn nnn    eee  tt
 SSSSS  kkkkk  yy   yy nnn  nn ee   e tttt
     SS kk kk   yyyyyy nn   nn eeeee  tt
 SSSSS  kk  kk      yy nn   nn  eeeee  tttt
                yyyyy
```
OPEN MQTT & COAP COMMUNICATIONS NETWORK & API FOR THE INTERNET OF THINGS (IoT)!

Visit [SKYNET.im](http://skynet.im) for up-to-the-latest documentation and screencasts.

======

Introduction
------------

SkyNet is an open source machine-to-machine instant messaging network and API. Our API supports both HTTP REST and realtime Web Sockets via RPC (remote procedure calls).  We also bridge [MQTT](http://mqtt.org) and [CoAP](http://en.wikipedia.org/wiki/Constrained_Application_Protocol) communications across our HTTP and Web Socket device channels.  

SkyNet auto-assigns 36 character UUIDs and secret tokens to each registered device connected to the network. These device credentials are used to authenticate with SkyNet and maintain your device's JSON description in our device directory.  

SkyNet allows you to query devices such as drones, hue light bulbs, weemos, arduinos, and server nodes that meet your criteria and send IM messages to 1 or all devices.

SkyNet includes a Node.JS NPM module called [SkyNet](http://skynet.im/#npm) and a [SkyNet.js](http://skynet.im/#javascript) file for simplifying Node.JS and mobile/client-side connectivity to SkyNet.

You can also subscribe to messages being sent to/from devices and their sensor activities.

Press
-----

[GigaOm](http://gigaom.com/2014/02/04/podcast-meet-skynet-an-open-source-im-platform-for-the-internet-of-things/) - Listen to Stacey Higginbotham from GigaOm interview Chris Matthieu, the founder of SkyNet, about our capabilities, uses, and future direction.

[Wired](http://www.wired.com/wiredenterprise/2014/02/skynet/) - ‘Yes, I’m trying to build SkyNet from Terminator.’

[LeapMotion](https://labs.leapmotion.com/46/) - Developer newsletter covers flying drones connected to SkyNet with LeapMotion sensor!

Roadmap
-------

* Phase 1 - Build a network and realtime API for enabling machine-to-machine communications.
* Phase 2 - Connect all of the thingz.
* Phase 3 - Become self-aware!

Installing
----------

Clone the git repository, then:

```bash
$ npm install
$ cp config.js.sample config.js
```

Modify `config.js` with your MongoDB connection string. If you have MongoDB running locally use:

```
mongodb://localhost:27017/skynet
```

You must also modify `config.js` with your Redis connection information. If you have Redis running locally use:

```
redisHost: "127.0.0.1",
redisPort: "6379"
```

Start the server use:

```bash
$ node server.js
```

Installing with Docker

The default Dockerfile will run Skynet, MongoDB and Redis in a single container to make quick experiments easier.

You'll need docker installed, then to build the Skynet image:

From the directory where the Dockerfile resides run.

```
# docker build -t=skynet .
```

To run a fully self contained instance using the source bundled in the container.

```
# docker run -i -t -p 3000 skynet
```

This will run skynet and expose port 3000 from the container on a random host port that you can find by running docker ps.

If you want to do development and run without rebuilding the image you can bind mount your source directory including node_modules onto the container. This example also binds a directory to hold the log of stdout & stderr from the Skynet node process.

```
# docker run -d -p 3000 --name=skynet_dev -v /path/to/your/skynet:/var/www -v /path/to/your/logs:/var/log/skynet skynet
```

If you change the code restarting the container is as easy as:

```
# docker restart skynet_dev
```

HTTP(S) REST API
----------------

GET /status

Returns the current status of the Skynet network

```
curl http://localhost:3000/status

=> {"skynet":"online","timestamp":1380480777750,"eventCode":200}
```

GET /devices

Returns an array of all devices available to you on Skynet. Notice you can query against custom properties i.e. all drones or light switches and online/offline etc.

```
curl http://localhost:3000/devices

curl http://localhost:3000/devices?key=123

curl http://localhost:3000/devices?online=true

curl http://localhost:3000/devices?key=123&online=true

=> ["ad698900-2546-11e3-87fb-c560cb0ca47b","2f3113d0-2796-11e3-95ef-e3081976e170","9c62a150-29f6-11e3-89e7-c741cd5bd6dd","f828ef20-29f7-11e3-9604-b360d462c699","d896f9f0-29fb-11e3-a27c-614201ddde6e"]
```

GET /devices/uuid

Returns all information on a given device by its UUID

```
curl http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26

=> {"_id":"5241d9140345450000000001","channel":"main","deviceDescription":"this is a test","deviceName":"hackboard","key":"123","online":true,"socketid":"pG5UAhaZa_xXlvrItvTd","timestamp":1380340661522,"uuid":"ad698900-2546-11e3-87fb-c560cb0ca47b"}b
```

POST /devices

Registers a device on the Skynet network. You can add as many properties to the device object as desired. Skynet returns a device UUID and token which needs to be used with future updates to the device object

Note: You can pass in a token parameter to overide skynet issuing you one

```
curl -X POST -d "name=arduino&description=this+is+a+test" http://localhost:3000/devices

curl -X POST -d "name=arduino&token=123" http://localhost:3000/devices

=> {"name":"arduino","description":"this is a test","uuid":"8220cff0-2939-11e3-88cd-0b8e5fdfd7d4","timestamp":1380481272431,"token":"1yw0nfc54okcsor2tfqqsuvnrcf2yb9","online":false,"_id":"524878f8cc12f0877f000003"}
```

PUT /devices/uuid

Updates a device object. Token is required for security.

```
curl -X PUT -d "token=123&online=true" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26

=> {"uuid":"8220cff0-2939-11e3-88cd-0b8e5fdfd7d4","timestamp":1380481439002,"online":true}
```

DELETE /devices/uuid

Unregisters a device on the Skynet network. Token is required for security.

```
curl -X DELETE -d "token=123" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26

=> {"uuid":"8220cff0-2939-11e3-88cd-0b8e5fdfd7d4","timestamp":1380481567799}
```

GET /mydevices/uuid

Returns all information (including tokens) of all devices or nodes belonging to a user's UUID (identified as "owner")

```
curl -X GET http://skynet.im/mydevices/0d1234a0-1234-11e3-b09c-1234e847b2cc?token=1234glm6y1234ldix1234nux41234sor

=> {"devices":[{"owner":"0d1234a0-1234-11e3-b09c-1234e847b2cc","name":"SMS","phoneNumber":"16025551234","uuid":"1c1234e1-xxxx-11e3-1234-671234c01234","timestamp":1390861609070,"token":"1234eg1234zz1tt1234w0op12346bt9","channel":"main","online":false,"_id":"52e6d1234980420c4a0001db"}}]}
```

POST /messages

Sends a JSON message to all devices or an array of devices or a specific device on the Skynet network.

```
curl -X POST -d '{"devices": "all", "message": {"yellow":"off"}}' http://localhost:3000/messages

curl -X POST -d '{"devices": ["ad698900-2546-11e3-87fb-c560cb0ca47b","2f3113d0-2796-11e3-95ef-e3081976e170"], "message": {"yellow":"off"}}' http://localhost:3000/messages

curl -X POST -d '{"devices": "ad698900-2546-11e3-87fb-c560cb0ca47b", "message": {"yellow":"off"}}' http://localhost:3000/messages

=> {"devices":"ad698900-2546-11e3-87fb-c560cb0ca47b","message":{"yellow":"off"},"timestamp":1380930482043,"eventCode":300}
```

GET /events/uuid?token=token

Returns last 10 events related to a specific device or node

```
curl -X GET http://skynet.im/events/ad698900-2546-11e3-87fb-c560cb0ca47b?token=123

=> {"events":[{"uuid":"0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc","socketid":"lnHHS06ijWUXEzb01ZRy","timestamp":1382632438785,"eventCode":101,"_id":"52694bf6ad11379eec00003f"},{"uuid":"0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc","socketid":"BuwnWQ_oLmpk5R3m1ZRv","timestamp":1382561240563,"eventCode":101,"_id":"526835d8ad11379eec000017"}]}
```

GET /subscribe/uuid?token=token

This is a streaming API that returns device/node mesages as they are sent and received. Notice the comma at the end of the response. SkyNet doesn't close the stream.

```
curl -X GET http://skynet.im/subscribe/ad698900-2546-11e3-87fb-c560cb0ca47b?token=123

=> [{"devices":"0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc","message":{"red":"on"},"timestamp":1388768270795,"eventCode":300,"_id":"52c6ec0e4f67671e44000001"},{"devices":"0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc","message":{"red":"on"},"timestamp":1388768277473,"eventCode":300,"_id":"52c6ec154f67671e44000002"},
```

GET /authenticate/uuid?token=token

Returns UUID and authticate: true or false based on the validity of uuid/token credentials

```
curl -X GET http://skynet.im/authenticate/81246e80-29fd-11e3-9468-e5f892df566b?token=5ypy4rurayktke29ypbi30kcw5ovfgvi

=> {"uuid":"81246e80-29fd-11e3-9468-e5f892df566b","authentication":true} OR {"uuid":"81246e80-29fd-11e3-9468-e5f892df566b","authentication":false}
```

GET /ipaddress

Returns the public IP address of the request. This is useful when working with the SkyNet Gateway behind a firewall.

```
curl -X GET http://skynet.im/ipaddress

=> {"ipAddress":"70.171.149.205"}
```

POST /data/uuid

Stores your device's sensor data to SkyNet

```
curl -X POST -d "token=123&temperature=78" http://skynet.im/data/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc

=> {"timestamp":"2014-03-25T16:38:48.148Z","uuid":"0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc","temperature":"30","ipAddress":"127.0.0.1","eventCode":700,"_id":"5331b118512c974805000002"}
```

GET /data/uuid

Retrieves your device's sensor data to SkyNet

```
curl -X GET http://localhost:3000/data/0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc?token=123

=> {"data":[{"timestamp":"2014-03-25T16:38:48.148Z","uuid":"0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc","temperature":"30","ipAddress":"127.0.0.1","id":"5331b118512c974805000001"},{"timestamp":"2014-03-23T18:57:16.093Z","uuid":"0d3a53a0-2a0b-11e3-b09c-ff4de847b2cc","temperature":"78","ipAddress":"127.0.0.1","id":"532f2e8c9c23809e93000001"}]}
```

CoAP API
--------

Our CoAP API works exactly like our REST API.  You can use [Matteo Collina's](https://twitter.com/matteocollina) [CoAP CLI](https://www.npmjs.org/package/coap-cli) for testing CoAP REST API calls.  Here are a few examples:

coap get coap://skynet.im/status

coap get coap://skynet.im/devices?type=drone

coap get coap://skynet.im/devices/ad698900-2546-11e3-87fb-c560cb0ca47b

coap post -p "type=drone&color=black" coap://skynet.im/devices

coap put -p "token=123&color=blue&online=true" coap://skynet.im/devices/ad698900-2546-11e3-87fb-c560cb0ca47b

coap delete -p "token=123" coap://skynet.im/devices/ad698900-2546-11e3-87fb-c560cb0ca47b


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

Event Codes
-----------

* 100 = Web socket connected
* 101 = Web socket identification
* 102 = Authenticate
* 200 = System status API call
* 201 = Get events
* 202 =
* 203 =
* 204 = Subscribe
* 205 = Unsubscribe
* 300 = Incoming message
* 301 = Incoming SMS message
* 302 = Outgoung SMS message
* 400 = Register device
* 401 = Update device
* 402 = Delete device
* 403 = Query devices
* 500 = WhoAmI
* 600 = Gateway Config API call
* 700 = Write sensor data

FOLLOW US!
----------

* [Twitter/SKYNETim](http://twitter.com/skynetim)
* [Facebook/SKYNETim](http://facebook.com/skynetim)
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
