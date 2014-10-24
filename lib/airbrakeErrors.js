var airbrake = require('airbrake').createClient(process.env.AIRBRAKE_KEY);

var handleExceptions = function() {
  var origConsoleError = console.error;
  airbrake.log = console.log;

  console.error = function(err) {
    if (err instanceof Error) {
      airbrake.notify(err);
      origConsoleError(err.message, err.stack);
    } else {
      airbrake.notify({error: arguments});
      origConsoleError.apply(this, arguments);
    }
  }

  process.on("uncaughtException", function(error) {
    return console.error(error);
  });
}

module.exports = {
  handleExceptions: handleExceptions
};
