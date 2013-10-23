```
 SSSSS  kk                            tt    
SS      kk  kk yy   yy nn nnn    eee  tt    
 SSSSS  kkkkk  yy   yy nnn  nn ee   e tttt  
     SS kk kk   yyyyyy nn   nn eeeee  tt    
 SSSSS  kk  kk      yy nn   nn  eeeee  tttt 
                yyyyy                         
```
======

Phase 1 - Build a network and realtime API for enabling machine-to-machine communications.

Here are several quick screencasts that demostrate what you can do with Skynet:

[POC Video 1](http://www.youtube.com/watch?v=cPs1JNFyXjk)

[POC Video 2](http://www.youtube.com/watch?v=SzaTPiaDDQI)

[POC Video 3](http://www.youtube.com/watch?v=TB6RyzT10EA)

[POC Video 4](http://www.youtube.com/watch?v=0WjNG6AOcXM)

[POC Video 5 - PubSub](https://www.youtube.com/watch?v=SL_c1MSgMaw)


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

=> {"_id":"5241d9140345450000000001","channel":"main","deviceDescription":"this is a test","deviceName":"hackboard","key":"123","online":true,"socketId":"pG5UAhaZa_xXlvrItvTd","timestamp":1380340661522,"uuid":"ad698900-2546-11e3-87fb-c560cb0ca47b"}b
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

POST /messages

Sends a JSON message to all devices or an array of devices or a specific device on the Skynet network. 

```
curl -X POST -d '{"devices": "all", "message": {"yellow":"off"}}' http://localhost:3000/messages

curl -X POST -d '{"devices": ["ad698900-2546-11e3-87fb-c560cb0ca47b","2f3113d0-2796-11e3-95ef-e3081976e170"], "message": {"yellow":"off"}}' http://localhost:3000/messages

curl -X POST -d '{"devices": "ad698900-2546-11e3-87fb-c560cb0ca47b", "message": {"yellow":"off"}}' http://localhost:3000/messages

=> {"devices":"ad698900-2546-11e3-87fb-c560cb0ca47b","message":{"yellow":"off"},"timestamp":1380930482043,"eventCode":300}
```

WEBSOCKET API
-------------

Request and receive system status

```
socket.emit('status', function (data) {
  console.log(data); 
});
```

Request and receive an array of devices matching a specific criteria

```
socket.emit('devices', {"key":"123"}, function (data) {
  console.log(data); 
});
```

Request and receive information about a specific device

```
socket.emit('whoami', {"uuid":"ad698900-2546-11e3-87fb-c560cb0ca47b"}, function (data) {
  console.log(data); 
});
```

Request and receive a device registration

```
socket.emit('register', {"key":"123"}, function (data) {
  console.log(data); 
});
```

Request and receive a device update

```
socket.emit('update', {"uuid":"ad698900-2546-11e3-87fb-c560cb0ca47b", "token": "zh4p7as90pt1q0k98fzvwmc9rmjkyb9", "key":"777"}, function (data) {
  console.log(data); 
});
```

Request and receive a device unregistration

```
socket.emit('unregister', {"uuid":"b5535950-29fd-11e3-9113-0bd381f0b5ef", "token": "2ls40jx80s9bpgb9w2g0vi2li72v5cdi"}, function (data) {
  console.log(data); 
});
```

Request and receive a message broadcast

```
// sending message to all devices
socket.emit('message', {"devices": "all", "message": {"yellow":"on"}});

// sending message to a specific devices
socket.emit('message', {"devices": "b5535950-29fd-11e3-9113-0bd381f0b5ef", "message": {"yellow":"on"}});

// sending message to an array of devices
socket.emit('message', {"devices": ["b5535950-29fd-11e3-9113-0bd381f0b5ef", "ad698900-2546-11e3-87fb-c560cb0ca47b"], "message": {"yellow":"on"}});
```

Event Codes
-----------

100 = Web socket connected

101 = Web socket identification

200 = System status API call

201 = 

202 =

203 =

300 = Incoming message

