module.exports  = {
  canView: function(fromUuid, toDevice){
    console.log('canView', fromUuid, toDevice);
    var viewable;
    if(fromUuid && toDevice){
      if(toDevice.owner == fromUuid || toDevice.uuid == fromUuid){
        return true;
      }else if(toDevice.viewWhitelist && toDevice.viewWhitelist.length){
        viewable = false;
        toDevice.viewWhitelist.forEach(function(id){
          if(id == fromUuid){
            viewable = true;
          }
        });
        return viewable;
      }else if(toDevice.viewBlacklist && toDevice.viewBlacklist.length){
        viewable = true;
        toDevice.viewBlacklist.forEach(function(id){
          if(id == fromUuid){
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
  canSend: function(fromUuid, toDevice){
    var viewable;
    if(fromUuid && toDevice){
      if(toDevice.owner == fromUuid){
        return true;
      }else if(toDevice.sendWhitelist && toDevice.sendWhitelist.length){
        viewable = false;
        toDevice.sendWhitelist.forEach(function(id){
          if(id == fromUuid){
            viewable = true;
          }
        });
        return viewable;
      }else if(toDevice.sendBlacklist && toDevice.sendBlacklist.length){
        viewable = true;
        toDevice.sendBlacklist.forEach(function(id){
          if(id == fromUuid){
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
  canUpdate: function(fromUuid, toDevice){
    if(fromUuid && toDevice){
      if(fromUuid != toDevice.uuid){
        //even if it isn't owned, will still need token
        return (toDevice.owner === fromUuid || !toDevice.owner);
      }else{
        return true;
      }
    }

    return false;
  }

};
