dashdash          = require 'dashdash'
UUID              = require 'uuid'
MeshbluCoreRunner = require './src/meshblu-core-runner'
packageJSON       = require './package.json'
SigtermHandler    = require 'sigterm-handler'

options = [
  {
    name: 'version'
    type: 'bool'
    help: 'Print tool version and exit.'
  }
  {
    names: ['help', 'h']
    type: 'bool'
    help: 'Print this help and exit.'
  }
  {
    names: ['namespace', 'n']
    type: 'string'
    help: 'request/response queue namespace'
    default: 'meshblu'
    env: 'NAMESPACE'
  }
  {
    names: ['request-queue-name']
    type: 'string'
    help: 'request queue namespace'
    default: 'v2:request:queue'
    env: 'REQUEST_QUEUE_NAME'
  }
  {
    names: ['response-queue-base-name']
    type: 'string'
    help: 'response queue base namespace'
    default: 'v2:response:queue'
    env: 'RESPONSE_QUEUE_BASE_NAME'
  }
  {
    names: ['single-run', 's']
    type: 'bool'
    help: 'perform only one job, then exit'
  }
  {
    names: ['timeout', 't']
    type: 'positiveInteger'
    help: 'seconds to wait for the next job'
    default: 15
  }
  {
    name: 'redis-uri'
    type: 'string'
    help: 'URI for Redis'
    env: 'REDIS_URI',
    default: 'redis://localhost:6379'
  }
  {
    name: 'cache-redis-uri'
    type: 'string'
    help: 'Cache URI for Redis'
    env: 'CACHE_REDIS_URI',
    default: 'redis://localhost:6379'
  }
  {
    name: 'firehose-redis-uri'
    type: 'string'
    help: 'URI for Firehose redis'
    env: 'FIREHOSE_REDIS_URI'
    default: 'redis://localhost:6379'
  }
  {
    name: 'mongodb-uri'
    type: 'string'
    help: 'URI for MongoDB'
    env: 'MONGODB_URI'
    default: 'mongodb://localhost:27017/meshblu-test'
  }
  {
    name: 'pepper'
    type: 'string'
    help: 'Pepper for encryption'
    env: 'PEPPER'
  }
  {
    name: 'alias-server-uri'
    type: 'string'
    help: 'URI for alias server'
    env: 'ALIAS_SERVER_URI'
  }
  {
    name: 'worker-name'
    type: 'string'
    help: 'name of this worker'
    env: 'WORKER_NAME'
  }
  {
    name: 'job-log-redis-uri'
    type: 'string'
    help: 'URI for job log Redis'
    env: 'JOB_LOG_REDIS_URI'
    default: 'redis://localhost:6379'
  }
  {
    name: 'job-log-queue'
    type: 'string'
    help: 'Job log queue name'
    env: 'JOB_LOG_QUEUE'
    default: 'meshblu-core-log'
  }
  {
    name: 'job-log-sample-rate'
    type: 'number'
    help: 'Job log sample rate (0.00 to 1.00)'
    env: 'JOB_LOG_SAMPLE_RATE'
    default: '0.00'
  }
  {
    name: 'job-timeout-seconds'
    type: 'positiveInteger'
    help: 'Timeout for job execution'
    env: 'JOB_TIMEOUT_SECONDS',
    default: 30
  }
  {
    name: 'max-connections'
    type: 'positiveInteger'
    help: 'Max number of redis connections of the http protocol'
    env: 'CONNECTION_POOL_MAX_CONNECTIONS',
    default: 50
  }
  {
    name: 'meshblu-http-port'
    type: 'positiveInteger'
    help: 'Port to listen on for HTTP'
    env: 'MESHBLU_HTTP_PORT',
    default: 80
  }
  {
    name: 'private-key-base64'
    type: 'string'
    help: 'Base64-encoded private key'
    env: 'PRIVATE_KEY_BASE64'
  }
  {
    name: 'public-key-base64'
    type: 'string'
    help: 'Base64-encoded public key'
    env: 'PUBLIC_KEY_BASE64'
  }
  {
    name: 'webhook-queue-name'
    type: 'string'
    env: 'WEBHOOK_QUEUE_NAME'
    default: 'webhooks'
    help: 'Name of Redis webhook work queue'
  },
  {
    name: 'webhook-queue-timeout'
    type: 'positiveInteger'
    env: 'WEBHOOK_QUEUE_TIMEOUT'
    default: 30
    help: 'BRPOP timeout (in seconds) for webhooks'
  },
  {
    name: 'webhook-request-timeout'
    type: 'positiveInteger'
    env: 'WEBHOOK_REQUEST_TIMEOUT'
    default: 5
    help: 'Request timeout (in seconds) for webhooks'
  },
  {
    name: 'webhook-namespace'
    type: 'string'
    env: 'WEBHOOK_NAMESPACE'
    default: 'meshblu-webhooks'
    help: 'Redis namespace for webhooks'
  }
]

parser = dashdash.createParser(options: options)
try
  opts = parser.parse(process.argv)
catch error
  console.error 'meshblu: error: %s', error.message
  process.exit 1

if opts.version
  console.log "meshblu v#{packageJSON.version}"
  process.exit 0

if opts.help
  help = parser.help({includeEnv: true, includeDefaults: true}).trimRight()
  console.log 'usage: node command.js [OPTIONS]\n' + 'options:\n' + help
  process.exit 0

if opts.private_key_base64?
  privateKey = new Buffer(opts.private_key_base64, 'base64').toString('utf8')

if opts.public_key_base64?
  publicKey = new Buffer(opts.public_key_base64, 'base64').toString('utf8')

meshbluConfig =
  hostname: 'localhost'
  port:     opts.meshblu_http_port
  protocol: 'http'

opts.pepper ||= process.env.TOKEN

options = {
  dispatcherWorker:
    namespace:           opts.namespace
    requestQueueName:    opts.request_queue_name
    timeoutSeconds:      opts.timeout
    redisUri:            opts.redis_uri
    cacheRedisUri:       opts.cache_redis_uri
    firehoseRedisUri:    opts.firehose_redis_uri
    mongoDBUri:          opts.mongodb_uri
    pepper:              opts.pepper
    workerName:          opts.worker_name
    aliasServerUri:      opts.alias_server_uri
    jobLogRedisUri:      opts.job_log_redis_uri
    jobLogQueue:         opts.job_log_queue
    jobLogSampleRate:    opts.job_log_sample_rate
    privateKey:          privateKey
    publicKey:           publicKey
    singleRun:           opts.single_run
  meshbluHttp:
    redisUri:              opts.redis_uri
    cacheRedisUri:         opts.cache_redis_uri
    requestQueueName:      opts.request_queue_name
    responseQueueName:     "#{opts.responseQueueBaseName}:#{UUID.v1()}"
    responseQueueBaseName: opts.response_queue_base_name
    namespace:             opts.namespace
    jobLogRedisUri:        opts.job_log_redis_uri
    jobLogQueue:           opts.job_log_queue
    jobLogSampleRate:      opts.job_log_sample_rate
    jobTimeoutSeconds:     opts.job_timeout_seconds
    maxConnections:        opts.max_connections
    port:                  opts.meshblu_http_port
  webhookWorker:
    namespace:           opts.webhook_namespace
    redisUri:            opts.redis_uri
    queueName:           opts.webhook_queue_name
    queueTimeout:        opts.webhook_queue_timeout
    requestTimeout:      opts.webhook_request_timeout
    jobLogRedisUri:      opts.job_log_redis_uri
    jobLogQueue:         opts.job_log_queue
    jobLogSampleRate:    opts.job_log_sample_rate
    privateKey:          privateKey
    meshbluConfig:       meshbluConfig
}

meshbluCoreRunner = new MeshbluCoreRunner options

sigtermHandler = new SigtermHandler({ events: ['SIGTERM', 'SIGINT'] })
sigtermHandler.register meshbluCoreRunner.stop

meshbluCoreRunner.catchErrors()

meshbluCoreRunner.prepare (error) =>
  if error
    meshbluCoreRunner.reportError error
    console.error error.stack
    process.exit 1

  meshbluCoreRunner.run (error) =>
    if error
      meshbluCoreRunner.reportError error
      console.error error.stack
      process.exit 1
    process.exit 0
