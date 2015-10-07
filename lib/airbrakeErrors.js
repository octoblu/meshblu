var airbrake = require('airbrake').createClient(process.env.AIRBRAKE_KEY);

var handleExceptions = function() {
  airbrake.handleExceptions.apply(airbrake, arguments);

  process.on("uncaughtException", function(error) {
    console.error(error.stack);
    process.exit(1);
  });
}

module.exports = {
  handleExceptions: handleExceptions
};
