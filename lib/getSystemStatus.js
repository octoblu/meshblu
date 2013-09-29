module.exports = function(req, res, next) {
  var status = {'skynet':'online'}
  require('./logEvent')(200, status);
  res.json(status);
}