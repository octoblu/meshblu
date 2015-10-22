class Publisher
  constructor: ({@uuid, @namespace}, {@client}={}) ->
    {createClient} = require './redis'
    @client ?= createClient()

  _channel: =>
    "#{@namespace}:#{@uuid}"

  publish: (message, callback) =>
    @client.publish @_channel(), JSON.stringify(message), callback

module.exports = Publisher
