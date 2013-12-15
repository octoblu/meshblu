function loadScript(url, callback)
{
    // Adding the script tag to the head as suggested before
    var head = document.getElementsByTagName('head')[0];
    var script = document.createElement('script');
    script.type = 'text/javascript';
    script.src = url;

    // Then bind the event to the callback function.
    // There are several events for cross browser compatibility.
    script.onreadystatechange = callback;
    script.onload = callback;

    // Fire the loading
    head.appendChild(script);
}

var authenticate = function() {

    skynet = io.connect('http://skynet.im', {
        port: 80
    });

    skynet.on('connect', function(){
      console.log('Requesting websocket connection to Skynet');

      skynet.on('identify', function(data){
        console.log('Websocket connecting to Skynet with socket id: ' + data.socketid);
        console.log('Sending device uuid: ' + skynetConfig.uuid);
        skynet.emit('identity', {uuid: skynetConfig.uuid, socketid: data.socketid, token: skynetConfig.token});
      });      

      skynet.on('notReady', function(data){
        console.log('Device not authenticated with Skynet');
        try {
          skynetNotReady();
        } catch(e){
          console.log('App not handling unauthorized access');
        }
      });
      skynet.on('ready', function(data){
        console.log('Device authenticated with Skynet');
        try {
          skynetReady();
        } catch(e){
          console.log('App not handling authorized access');
        }

      });

    });

};

loadScript("http://skynet.im/socket.io/socket.io.js", authenticate);
