class Publisher
  constructor: (options={}, dependencies={}) ->
    {@namespace} = options
    {@client} = dependencies
    @namespace ?= 'meshblu'
    {createClient} = require './redis'
    @client ?= createClient()

  publish: (type, uuid, message, callback) =>
    channel = "#{@namespace}:#{type}:#{uuid}"
    return callback new Error("Invalid message") unless message?
    @client.publish channel, JSON.stringify(message), callback

module.exports = Publisher
