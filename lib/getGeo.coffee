_      = require 'lodash'

module.exports = (ipAddress, callback=_.noop, dependencies={}) ->
  return callback new Error('Invalid IP Address') unless ipAddress

  {lookup} = dependencies.geoip ? require './geoip'
  geo = lookup(ipAddress)

  return callback new Error('No Geo data for IP Address') unless geo

  callback null, geo
