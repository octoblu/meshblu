class MeshbluAuthParser
  parse: (request) =>
    authPair  = @parseBasicAuth request
    authPair ?= @parseMeshbluAuthHeaders request
    authPair ?= @parseSkynetAuthHeaders request
    authPair ?= @parseExtraHeaders request
    authPair ?= {uuid: undefined, token: undefined}
    return authPair

  parseBasicAuth: (request) =>
    return unless request.header 'authorization'
    [scheme,encodedToken] = request.header('authorization').split(' ')
    [uuid,token] = new Buffer(encodedToken, 'base64').toString().split(':')

    return {
      uuid:  uuid.trim?()
      token: token.trim?()
    }

  parseMeshbluAuthHeaders: (request) =>
    return @parseHeader request, 'meshblu_auth_uuid', 'meshblu_auth_token'

  parseSkynetAuthHeaders: (request) =>
    return @parseHeader request, 'skynet_auth_uuid', 'skynet_auth_token'

  parseExtraHeaders: (request) =>
    return @parseHeader request, 'X-Meshblu-UUID', 'X-Meshblu-Token'

  parseHeader: (request, uuidHeader, tokenHeader) =>
    return unless request.header(uuidHeader) and request.header(tokenHeader)
    uuid  = request.header(uuidHeader).trim()
    token = request.header(tokenHeader).trim()
    return {uuid:uuid, token:token}

module.exports = MeshbluAuthParser
