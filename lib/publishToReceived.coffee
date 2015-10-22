Publisher = require './Publisher'

module.exports = (uuid, message, callback) =>
  publisher = new Publisher uuid: uuid, namespace: 'meshblu:received'
  publisher.publish message, callback
