_ = require 'lodash'

class LogError
  constructor: ->
    if process.env.AIRBRAKE_KEY
      @airbrake = require('airbrake').createClient process.env.AIRBRAKE_KEY

  log: (error) =>
    return if error?.message == 'Device not found'
    console.error.apply console, arguments
    return unless _.isError error
    @airbrake?.notify error
    console.error error.stack

logError = new LogError()
module.exports = logError.log
