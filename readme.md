skynet
======

Phase 1 - Build a network and realtime API for enabling machine-to-machine communications.

API
---

GET /status
Returns the current status of the Skynet network
curl http://localhost:3000/status
=> {"skynet":"online","timestamp":1380480777750,"eventCode":200}

GET /devices
Returns all devices available to you on Skynet. Notice you can query against custom properties i.e. all drones or light switches or online/office etc.
curl http://localhost:3000/devices
curl http://localhost:3000/devices?key=123
curl http://localhost:3000/devices?online=true
=> [{"_id":"5241d9140345450000000001","channel":"main","deviceDescription":"this is a test","deviceName":"hackboard","key":"123","online":true,"socketId":"pG5UAhaZa_xXlvrItvTd","timestamp":1380340661522,"uuid":"ad698900-2546-11e3-87fb-c560cb0ca47b"},{"uuid":"2f3113d0-2796-11e3-95ef-e3081976e170","timestamp":1380301174157,"online":false,"_id":"5245b977f1eef01357000001"}]

GET /devices/uuid
Returns all information on a given device by its UUID
curl http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
=> {"_id":"5241d9140345450000000001","channel":"main","deviceDescription":"this is a test","deviceName":"hackboard","key":"123","online":true,"socketId":"pG5UAhaZa_xXlvrItvTd","timestamp":1380340661522,"uuid":"ad698900-2546-11e3-87fb-c560cb0ca47b"}b

POST /devices
Registers a device on the Skynet network. You can add as many properties to the device object as desired. Skynet returns a device UUID and token which needs to be used with future updates to the device object
curl -X POST -d "name=arduino&description=this+is+a+test" http://localhost:3000/devices
=> {"name":"arduino","description":"this is a test","uuid":"8220cff0-2939-11e3-88cd-0b8e5fdfd7d4","timestamp":1380481272431,"token":"1yw0nfc54okcsor2tfqqsuvnrcf2yb9","online":false,"_id":"524878f8cc12f0877f000003"}

PUT /devices/uuid
Updates a device object. Token is required for security.
curl -d "token=123&online=true" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
=> {"uuid":"8220cff0-2939-11e3-88cd-0b8e5fdfd7d4","timestamp":1380481439002,"online":true}

DELETE /devices/uuid
Unregisters a device on the Skynet network. Token is required for security.
curl -X DELETE -d "token=123" http://localhost:3000/devices/01404680-2539-11e3-b45a-d3519872df26
=> {"uuid":"8220cff0-2939-11e3-88cd-0b8e5fdfd7d4","timestamp":1380481567799}

POST /messages/all
Sends a JSON message to all devices on the Skynet network. 
curl -X POST -d '{"blink":"start"}' http://localhost:3000/messages/all
curl -X POST -d '{"blink":"stop"}' http://localhost:3000/messages/all
=> {"socketid":"all","body":{"blink":"start"}

POST /messages/uuid
Sends a JSON message to a specific device on the Skynet network. 
curl -X POST -d '{"blink":"start"}' http://localhost:3000/messages/ad698900-2546-11e3-87fb-c560cb0ca47b
curl -X POST -d '{"blink":"stop"}' http://localhost:3000/messages/ad698900-2546-11e3-87fb-c560cb0ca47b
=> {"socketid":"pG5UAhaZa_xXlvrItvTd","body":{"blink":"start"}}


Event Codes
-----------

100 = Web socket connected
101 = Web socket identification
200 = System status API call
201 = 
202 =
203 =
300 = Incoming message

