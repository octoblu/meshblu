async = require 'async'
redis = require './lib/redis'
authDevice = require './lib/authDevice'
sendMessageCreator = require './lib/sendMessage'
createMessageIOEmitter = require './lib/createMessageIOEmitter'

class Worker
  constructor: ->
    @_sendMessage = sendMessageCreator createMessageIOEmitter()

  run: =>
    async.whilst @true, @popMessage, (error) =>
      console.error 'whilst error:', error.stack

  true: => true

  popMessage: (callback) =>
    redis.brpop 'meshblu-messages', 1, (err, result) =>
      return callback err if err?
      return callback() unless result?
      [queueName, jobStr] = result
      @processJobStr jobStr, callback

  parseJob: (jobStr, callback) =>
    try
      callback null, JSON.parse jobStr
    catch error
      callback error

  processJobStr: (jobStr, callback) =>
    @parseJob jobStr, (error, job) =>
      return callback error if error?

      @processJob job, callback

  processJob: (job, callback) =>
    {uuid,token,message} = job

    authDevice uuid, token, (error, device) =>
      return callback error if error?

      @sendMessage device, message, message.topic, callback

  sendMessage: (device, message, topic, callback) =>
    @_sendMessage device, message, topic
    callback()

worker = new Worker()
worker.run()
