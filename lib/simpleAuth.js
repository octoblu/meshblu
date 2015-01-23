var util = require('./util');
var bcrypt = require('bcrypt');

module.exports  = {
  canDiscover: function(fromDevice, toDevice){
    var viewable;
    if (!fromDevice || !toDevice) {
      return false;
    }

    if (toDevice.uuid === fromDevice.uuid) {
      return true;
    }

    if (toDevice.owner === fromDevice.uuid) {
      return true;
    }

    if(toDevice.discoverWhitelist && toDevice.discoverWhitelist.length){
      viewable = false;
      toDevice.discoverWhitelist.forEach(function(id){
        if(id == fromDevice.uuid){
          viewable = true;
        }
      });
      return viewable;
    }

    if(toDevice.discoverBlacklist && toDevice.discoverBlacklist.length) {
      viewable = true;
      toDevice.discoverBlacklist.forEach(function(id){
        if(id == fromDevice.uuid){
          viewable = false;
        }
      });
      return viewable;
    }

    return true;
  },
  canReceive: function(fromDevice, toDevice){
    var receivable;
    if(fromDevice && toDevice){
      if(toDevice.owner == fromDevice.uuid){
        return true;
      }else if(toDevice.receiveWhitelist && toDevice.receiveWhitelist.length){
        receivable = false;
        toDevice.receiveWhitelist.forEach(function(id){
          if(id == fromDevice.uuid){
            receivable = true;
          }
        });
        return receivable;
      }else if(toDevice.receiveBlacklist && toDevice.receiveBlacklist.length){
        receivable = true;
        toDevice.receiveBlacklist.forEach(function(id){
          if(id == fromDevice.uuid){
            receivable = false;
          }
        });
        return receivable;
      } else {
        return true;
      }
    }

    return false;
  },
  canSend: function(fromDevice, toDevice){
    var viewable;
    if(fromDevice && toDevice){
      if(toDevice.owner == fromDevice.uuid){
        return true;
      }else if(toDevice.sendWhitelist && toDevice.sendWhitelist.length){
        viewable = false;
        toDevice.sendWhitelist.forEach(function(id){
          if(id == fromDevice.uuid){
            viewable = true;
          }
        });
        return viewable;
      }else if(toDevice.sendBlacklist && toDevice.sendBlacklist.length){
        viewable = true;
        toDevice.sendBlacklist.forEach(function(id){
          if(id == fromDevice.uuid){
            viewable = false;
          }
        });
        return viewable;
      } else {
        return true;
      }
    }

    return false;
  },
  canConfigure: function(fromDevice, toDevice, message){
    if( toDevice && toDevice.token && message && message.token ) {
      if (bcrypt.compareSync(message.token, toDevice.token)) {
        return true;
      }
    }

    if(fromDevice && toDevice){
      if(fromDevice.uuid != toDevice.uuid){

        if(!toDevice.owner){
          //not owned, same local network?
          return util.sameLAN(fromDevice.ipAddress, toDevice.ipAddress);
        }
        else{
          //owned by fromDevice?`
          return (toDevice.owner === fromDevice.uuid);
        }

      }else{
        return true;
      }
    }

    return false;
  }

};
