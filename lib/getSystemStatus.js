module.exports = function(callback) {
  var status = {'skynet':'online'};
  require('./logEvent')(200, status);
  callback(status);
}