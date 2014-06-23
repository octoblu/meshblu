var util = require('./util');

module.exports  = {
  canView: function(fromDevice, toDevice){
    //console.log('canView', fromDevice, toDevice);
    var viewable;
    if(fromDevice && toDevice){
      if(toDevice.owner == fromDevice.uuid){
        return true;
      }else if(toDevice.viewWhitelist && toDevice.viewWhitelist.length){
        viewable = false;
        toDevice.viewWhitelist.forEach(function(id){
          if(id == fromDevice.uuid){
            viewable = true;
          }
        });
        return viewable;
      }else if(toDevice.viewBlacklist && toDevice.viewBlacklist.length){
        viewable = true;
        toDevice.viewBlacklist.forEach(function(id){
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
  canRead: function(fromDevice, toDevice){
    console.log('canRead', fromDevice, toDevice);
    var readable;
    if(fromDevice && toDevice){
      if(toDevice.owner == fromDevice.uuid){
        return true;
      }else if(toDevice.readWhitelist && toDevice.readWhitelist.length){
        readable = false;
        toDevice.readWhitelist.forEach(function(id){
          if(id == fromDevice.uuid){
            readable = true;
          }
        });
        return readable;
      }else if(toDevice.readBlacklist && toDevice.readBlacklist.length){
        readable = true;
        toDevice.readBlacklist.forEach(function(id){
          if(id == fromDevice.uuid){
            readable = false;
          }
        });
        return readable;
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
  canUpdate: function(fromDevice, toDevice){
    if(fromDevice && toDevice){
      if(fromDevice.uuid != toDevice.uuid){

        if(!toDevice.owner){
          //not owned, same local network?
          return util.sameLAN(fromDevice.ipAddress, toDevice.ipAddress);
        }
        else{
          //owned by fromDevice?
          return (toDevice.owner === fromDevice.uuid);
        }

      }else{
        return true;
      }
    }

    return false;
  }

};
