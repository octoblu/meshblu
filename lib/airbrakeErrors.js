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
      airbrake.notify({error: arguments});
    }
  }

  process.on("uncaughtException", function(error) {
    console.error(error);
  });
}

module.exports = {
  handleExceptions: handleExceptions
};
