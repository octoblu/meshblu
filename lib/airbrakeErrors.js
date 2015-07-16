var airbrake = require('airbrake').createClient(process.env.AIRBRAKE_KEY);
var circular = require('circular');

var handleExceptions = function() {
  var origConsoleError = console.error;
  airbrake.log = console.log;

  console.error = function(err) {
    if (err instanceof Error) {
      origConsoleError(err.message, err.stack);
      airbrake.notify(err);
    } else {
      origConsoleError.apply(this, arguments);
      var error = new Error("generic error that I can't tell you about, or airbrake will crash.");
      error.parameters = circular(arguments);
      airbrake.notify(error);
    }
  }

  process.on("uncaughtException", function(error) {
    console.error(error);
    process.exit(1);
  });
}

module.exports = {
  handleExceptions: handleExceptions
};
