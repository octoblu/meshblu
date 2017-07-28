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
    unless options.webhookWorker.disable
      @webhookWorker    = new WebhookWorker options.webhookWorker

  catchErrors: =>
    debug '->catchErrors'
    @dispatcherWorker.catchErrors()

  destroy: (callback) =>
    debug '->destroy'
    tasks = []
    tasks.push (next) =>
      @meshbluHttp.destroy (error) =>
        next error
    tasks.push (next) =>
      next()
      @dispatcherWorker.stop (error) =>
        throw error if error?
     tasks.push (next) =>
      return next() unless @webhookWorker?
      @webhookWorker.stop (error) =>
        next error

    async.parallel tasks, callback

  prepare: (callback) =>
    debug '->prepare'
    @dispatcherWorker.prepare callback

  reportError: =>
    debug '->reportError'
    @dispatcherWorker.reportError arguments...

  stop: (callback) =>
    debug '->stop'
    tasks = []
    tasks.push @meshbluHttp.stop
    tasks.push @dispatcherWorker.stop
    tasks.push @webhookWorker.stop if @webhookWorker?
    async.parallel tasks, callback

  run: (callback) =>
    debug '->run'
    @dispatcherWorker.run (error) =>
      @emit 'error', error if error?

    @webhookWorker?.start (error) =>
      @emit 'error', error if error?

    @meshbluHttp.run callback

module.exports = MeshbluCoreRunner
