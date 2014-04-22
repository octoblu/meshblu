/* coapRequest Notes
 * ============================================================
 *
 * This is to demonstrate and test coap requests against skynet.
 * I haven't added any flags yet for posting data, but they are to follow.
 *
 * Usage
 * -----
 *
 *  node coapRequest coap://skynet-server/path
 *
 * or
 *
 *  node coapRequest
 *
 * The first example will grab whatever path you send it as an argument
 * The second example will default to coap://localhost/status
 */

var params = process.argv[2] || 'coap://localhost/status',
    stream = require('stream'),
    coap   = require('coap');

console.log('Making request', params);
var req = coap.request(params);
req.on('response', function (res) {
  var dataStream = new stream.Transform(),
      data;

  res.on('data', function (chunk) {
    data = data ? Buffer.concat([data, chunk]) : chunk;
  });

  res.on('end', function () {
    dataStream.push(data.toString());
    dataStream.pipe(process.stdout);
  });
});

req.end();
