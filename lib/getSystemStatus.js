var _ = require('lodash');

module.exports = function(callback) {
  callback = callback || function(){};
  _.defer(callback, {meshblu: 'online'});
}
