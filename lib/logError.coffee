_ = require 'lodash'

class LogError
  constructor: ->
    if process.env.AIRBRAKE_KEY
      @airbrake = require('airbrake').createClient process.env.AIRBRAKE_KEY

  log: (error) =>
    @airbrake?.notify error
    console.error.apply console, arguments
    console.error error.stack if _.isError error

logError = new LogError()
module.exports = logError.log
