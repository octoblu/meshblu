var airbrake = require('airbrake').createClient(process.env.AIRBRAKE_KEY);

var handleExceptions = function() {
  var origConsoleError = console.error;
  airbrake.log = console.log;

  console.error = function(err) {
    if (err instanceof Error) {
      origConsoleError(err.message, err.stack);
      airbrake.notify(err);
    } else {
      origConsoleError.apply(this, arguments);
      var error = new Error('generic error');
      error.parameters = arguments;
      airbrake.notify(error);
    }
  }

  process.on("uncaughtException", function(error) {
    console.error(error);
  });
}

module.exports = {
  handleExceptions: handleExceptions
};
