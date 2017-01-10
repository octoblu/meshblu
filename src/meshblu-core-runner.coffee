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

  destroy: (callback) =>
    debug '->destroy'
    async.parallel [
      @meshbluHttp.destroy,
      @dispatcherWorker.stop
      @webhookWorker.stop
    ], callback

  prepare: (callback) =>
    debug '->prepare'
    @dispatcherWorker.prepare(callback)

  reportError: =>
    debug '->reportError'
    @dispatcherWorker.reportError arguments...

  stop: (callback) =>
    debug '->stop'
    async.parallel [
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
