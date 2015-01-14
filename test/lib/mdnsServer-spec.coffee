mdnsServer = require '../../lib/mdnsServer'

describe 'mdnsServer', ->
  it 'should be a function', ->
    expect(mdnsServer).to.be.a 'function'

  describe 'when we override the mdns dependency', ->
    beforeEach ->
      @fakeMdns = new FakeMdns

    describe 'with a port of 10', ->
      beforeEach ->
        @result = mdnsServer {port: '10'}, {mdns: @fakeMdns}

      it 'should return the result of createAdvertisement', ->
        expect(@result).to.equal @fakeMdns.createAdvertisementReturnValue

      it 'should call createAdvertisement with result of mdns.tcp and the port', ->
        expect(@fakeMdns.createAdvertisement).to.have.been.calledWith @fakeMdns.tcp('meshblu'), 10

      it 'should call tcp with "meshblu"', ->
        expect(@fakeMdns.tcp).to.have.been.calledWith 'meshblu'

    describe 'with a port of 30', ->
      beforeEach ->
        @result = mdnsServer {port: '30'}, {mdns: @fakeMdns}

      it 'should call createAdvertisement with result of mdns.tcp and the port', ->
        expect(@fakeMdns.createAdvertisement).to.have.been.calledWith @fakeMdns.tcp('meshblu'), 30

    describe 'with a port of 09', ->
      beforeEach ->
        @result = mdnsServer {port: '09'}, {mdns: @fakeMdns}

      it 'should call createAdvertisement with result of mdns.tcp and the port', ->
        expect(@fakeMdns.createAdvertisement).to.have.been.calledWith @fakeMdns.tcp('meshblu'), 9



class FakeMdns
  constructor: (@createAdvertisementReturnValue={}, @tcpReturnValue={}) ->
    @createAdvertisement = sinon.spy(@createAdvertisement)
    @tcp = sinon.spy(@tcp)

  createAdvertisement: =>
    @createAdvertisementReturnValue

  tcp: =>
    @tcpReturnValue


