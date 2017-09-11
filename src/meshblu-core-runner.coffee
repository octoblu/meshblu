async            = require('async')
{EventEmitter}   = require 'events'
DispatcherWorker = require('meshblu-core-dispatcher')
MeshbluHttp      = require('meshblu-core-protocol-adapter-http')
MeshbluFirehose  = require('meshblu-core-firehose-socket.io')
WebhookWorker    = require('meshblu-core-worker-webhook')
debug            = require('debug')('meshblu:meshblu-core-runner')

class MeshbluCoreRunner extends EventEmitter
  constructor: (options) ->
    @dispatcherWorker = new DispatcherWorker options.dispatcherWorker
    @meshbluHttp = new MeshbluHttp options.meshbluHttp
    if @_isFirehoseEnabled options
      @meshbluFirehose = new MeshbluFirehose options.meshbluFirehose
    if @_isWebhookWorkerEnabled options
      @webhookWorker = new WebhookWorker options.webhookWorker

  catchErrors: =>
    debug '->catchErrors'
    @dispatcherWorker.catchErrors()

  destroy: (callback) =>
    debug '->destroy'
    tasks = []
    tasks.push @meshbluHttp.destroy
    tasks.push @meshbluFirehose.stop if @meshbluFirehose?
    tasks.push @dispatcherWorker.stop
    tasks.push @webhookWorker.stop if @webhookWorker?
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
    tasks.push @meshbluFirehose.stop if @meshbluFirehose?
    tasks.push @dispatcherWorker.stop
    tasks.push @webhookWorker.stop if @webhookWorker?
    async.parallel tasks, callback

  run: (callback) =>
    debug '->run'
    @dispatcherWorker.run (error) =>
      @emit 'error', error if error?

    @webhookWorker?.start (error) =>
      @emit 'error', error if error?

    @meshbluFirehose?.run (error) =>
      @emit 'error', error if error?

    @meshbluHttp.run callback

  _isFirehoseEnabled: (options) =>
    return false unless options.meshbluFirehose?
    return !options.meshbluFirehose.disable

  _isWebhookWorkerEnabled: (options) =>
    return false unless options.webhookWorker?
    return !options.webhookWorker.disable

module.exports = MeshbluCoreRunner
