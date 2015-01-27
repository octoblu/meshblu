_            = require 'lodash'
bcrypt       = require 'bcrypt'
util = require '../../lib/util'

describe 'simpleAuth', ->
  beforeEach ->
    @sut = require '../../lib/simpleAuth'

  it 'should exist', ->
    expect(@sut).to.exist

  describe 'canDiscover', ->
    it 'should exist', ->
      expect(@sut.canDiscover).to.exist

    describe 'when fromDevice is undefined', ->
      it 'should return false', ->
        expect(@sut.canDiscover(undefined, uuid: 1)).to.be.false

    describe 'when toDevice is undefined', ->
      it 'should return false', ->
        expect(@sut.canDiscover( uuid: 1)).to.be.false

    describe 'when fromDevice is the same device as toDevice', ->
      beforeEach ->
        @fromDevice = uuid: 1
        @toDevice = uuid: 1
      it 'should return true', ->
        expect(@sut.canDiscover @fromDevice, @toDevice).to.be.true

    describe 'when fromDevice is a different device than toDevice', ->
      beforeEach ->
        @fromDevice = uuid: 1
        @toDevice = uuid: 2

      it 'should return false', ->
        expect(@sut.canDiscover @fromDevice, @toDevice).to.be.true

      describe 'when toDevice has a discoverWhitelist that doesn\'t have fromDevice\'s uuid', ->
        beforeEach ->
          @toDevice.discoverWhitelist = [5]

        it 'should return false', ->
          expect(@sut.canDiscover @fromDevice, @toDevice).to.be.false


    describe 'when fromDevice owns toDevice', ->
      beforeEach ->
        @fromDevice = owner: 4321, uuid: 1234
        @toDevice = owner: 1234, uuid: 2222

      it 'should return true', ->
        expect(@sut.canDiscover @fromDevice, @toDevice).to.be.true

    describe 'when fromDevice is in the toDevice\'s discoverBlacklist', ->
      beforeEach ->
        @fromDevice = uuid: 1234
        @toDevice = uuid: 2222, discoverBlacklist: [ 1234 ]

      it 'should return false', ->
        expect( @sut.canDiscover @fromDevice, @toDevice).to.be.false

  describe 'canConfigure', ->
    it 'should exist', ->
      expect(@sut.canConfigure).to.exist

    describe 'when fromDevice is undefined', ->
      it 'should return false', ->
        expect(@sut.canConfigure undefined, uuid: 1).to.be.false

    describe 'when toDevice is undefined', ->
      it 'should return false', ->
        expect(@sut.canConfigure uuid: 1, undefined).to.be.false

    describe 'when toDevice is the same as fromDevice', ->
      beforeEach ->
        @fromDevice = uuid: 1
        @toDevice = uuid: 1

      it 'should return true', ->
        expect(@sut.canConfigure @fromDevice, @toDevice).to.be.true

    describe 'when toDevice is different from fromMessage, and has sent a message that includes the token of toDevice', ->
      beforeEach ->
        @fromDevice = uuid: 1
        @toDevice = uuid: 2, token: bcrypt.hashSync('5555',1)
        @message = token: '5555'

      it 'should return true', ->
        expect(@sut.canConfigure @fromDevice, @toDevice, @message).to.be.true

    describe 'when toDevice is different from fromMessage, and has sent a message that includes a random uuid', ->
      beforeEach ->
        @fromDevice = uuid: 1
        @toDevice = uuid: 2, token: bcrypt.hashSync('69',1)
        @message = token: '5555'

      it 'should return false', ->
        expect(@sut.canConfigure @fromDevice, @toDevice, @message).to.be.false

    describe 'when the owner of a device sends a configure command, but gets the token wrong', ->
      beforeEach ->
        @fromDevice = uuid: 1
        @toDevice = uuid: 2, token: bcrypt.hashSync('69',1), owner: 1
        @message = token: '5555'

      it 'should do it anyway', ->
        expect(@sut.canConfigure @fromDevice, @toDevice, @message).to.be.true

    describe 'when a device is unclaimed, and exists on the same lan as the configuring device', ->
      beforeEach ->
        @fromDevice = uuid: 1
        @toDevice = uuid: 2
        util.sameLAN = sinon.stub().returns true

      it 'should return true', ->
        expect(@sut.canConfigure @fromDevice, @toDevice).to.be.true



    describe 'when a device is unclaimed, and exists on a different lan than the configuring device', ->
      beforeEach ->
        @fromDevice = uuid: 1, ipAddress: '127.0.0.1'
        @toDevice = uuid: 2, ipAddress: '192.168.0.1'
        util.sameLAN = sinon.stub().returns false
        @result = @sut.canConfigure @fromDevice, @toDevice

      it 'should return false', ->
        expect(@result).to.be.false

      it 'should call sameLan with the ipAddresses of both devices', ->
        expect(util.sameLAN).to.have.been.calledWith '127.0.0.1', '192.168.0.1'

