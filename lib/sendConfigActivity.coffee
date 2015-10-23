getDevice = require './getDevice'
Publisher = require './Publisher'

publisher = new Publisher

sendConfigActivity = (uuid) =>
  getDevice uuid, (error, device) =>
    publisher.publish 'config', uuid, device

module.exports = sendConfigActivity
