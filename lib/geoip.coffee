_ = require 'lodash'

try
  geoip = require 'geoip-lite'
catch e
  geoip = {lookup: _.noop}

module.exports = geoip
