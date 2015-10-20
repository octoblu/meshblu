_ = require 'lodash'
process.env.MESSAGE_BUS_PORT = "" + _.random 10000, 50000

async = require 'async'
redis = require './lib/redis'
authDevice = require './lib/authDevice'
sendMessageCreator = require './lib/sendMessage'
createMessageIOEmitter = require './lib/createMessageIOEmitter'
MessageIO = require './lib/MessageIO'

class Worker
  constructor: ->
    messageIO = new MessageIO()
    messageIO.start()

    redisStore = redis.createIoStore()
    messageIO.setAdapter redisStore

    @_sendMessage = sendMessageCreator createMessageIOEmitter messageIO.io
    @redis = redis.createClient()

  run: =>
    async.whilst @true, @popMessage, (error) =>
      console.error 'whilst error:', error.stack

  true: => true

  popMessage: (callback) =>
    @redis.brpop 'meshblu-messages', 60, (err, result) =>
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
    {auth,message,http} = job
    {uuid,token} = auth

    authDevice uuid, token, (error, device) =>
      return callback error if error?

      @sendMessage device, message, callback

  sendMessage: (device, message, callback) =>
    @_sendMessage device, message
    callback()

worker = new Worker()
worker.run()
