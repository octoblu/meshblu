class Publisher
  constructor: ({@namespace}={}, {@client}={}) ->
    @namespace ?= 'meshblu'
    {createClient} = require './redis'
    @client ?= createClient()

  publish: (type, uuid, message, callback) =>
    channel = "#{@namespace}:#{type}:#{uuid}"
    @client.publish channel, JSON.stringify(message), callback

module.exports = Publisher
