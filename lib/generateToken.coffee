crypto       = require 'crypto'

generateToken = ->
  return crypto.createHash('sha1').update((new Date()).valueOf().toString() + Math.random().toString()).digest('hex');

module.exports = generateToken
