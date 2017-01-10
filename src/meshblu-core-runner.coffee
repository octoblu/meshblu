async            = require('async')
{EventEmitter}   = require 'events'
DispatcherWorker = require('meshblu-core-dispatcher')
MeshbluHttp      = require('meshblu-core-protocol-adapter-http')
WebhookWorker    = require('meshblu-core-worker-webhook')
debug            = require('debug')('meshblu:meshblu-core-runner')

class MeshbluCoreRunner extends EventEmitter
  constructor: (options) ->
    @dispatcherWorker = new DispatcherWorker options.dispatcherWorker
    @meshbluHttp      = new MeshbluHttp options.meshbluHttp
    @webhookWorker    = new WebhookWorker options.webhookWorker

  catchErrors: =>
    debug '->catchErrors'
    @dispatcherWorker.catchErrors()

  reportError: =>
    debug '->reportError'
    @dispatcherWorker.reportError arguments...

  prepare: (callback) =>
    debug '->prepare'
    @dispatcherWorker.prepare(callback)

  stop: (callback) =>
    debug '->stop'
    async.series [
      @meshbluHttp.stop,
      @dispatcherWorker.stop
      @webhookWorker.stop
    ], callback

  run: (callback) =>
    debug '->run'
    @dispatcherWorker.run (error) =>
      @emit 'error', error if error?

    @webhookWorker.run (error) =>
      @emit 'error', error if error?

    @meshbluHttp.run callback

module.exports = MeshbluCoreRunner
