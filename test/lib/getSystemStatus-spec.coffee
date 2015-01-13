getSystemStatus = require '../../lib/getSystemStatus'

describe 'getSystemStatus', ->
  it 'should exist', ->
    expect(getSystemStatus).to.be.a 'function'

  describe 'called with a callback', ->
    it 'should call the callback with a status of {meshblu: "online"}', (done) ->
      getSystemStatus (result) ->
        expect(result).to.deep.equal {meshblu: 'online'}
        done()

  describe 'called without a callback', ->
    it 'should not crash', ->
      getSystemStatus()
