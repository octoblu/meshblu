_ = require 'lodash'

class LogError
  constructor: ->
    if process.env.AIRBRAKE_KEY
      @airbrake = require('airbrake').createClient process.env.AIRBRAKE_KEY

  log: (error) =>
    console.error.apply console, arguments
    if _.isError error
      @airbrake?.notify error
      console.error error.stack

logError = new LogError()
module.exports = logError.log
