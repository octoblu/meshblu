_ = require 'lodash'

module.exports = (fromDevice, query, callback=_.noop, dependencies={})->
  securityImpl = dependencies.securityImpl ? require('./getSecurityImpl')
  getDevice = dependencies.getDevice ? require('./getDevice')

  getDevice query.uuid, (error, toDevice) =>
    securityImpl.canDiscover fromDevice, toDevice, query, (error, permission) =>
      return callback error if error?
      return callback new Error 'unauthorized' unless permission
      callback null, toDevice
