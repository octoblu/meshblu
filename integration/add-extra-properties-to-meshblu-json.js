var path = require('path');
var fs   = require('fs');

var meshbluJSONPath = path.join(__dirname, 'meshblu.json');
var meshbluJSONStr = fs.readFileSync(meshbluJSONPath)
var meshbluJSON = {}
try{
  meshbluJSON = JSON.parse(meshbluJSONStr);
}catch(error){
  console.error(error.stack);
  return;
}
meshbluJSON.protocol = 'http';
meshbluJSON.host = 'localhost:3000';
fs.writeFileSync(meshbluJSONPath, JSON.stringify(meshbluJSON, null, 2));
