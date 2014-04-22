var qs = require('qs'),
    _  = require('lodash');

var coapRouter = {
  routes : [],
  compilePattern : function (pattern) {
    if(pattern instanceof RegExp) return pattern;
    
    var fragments = pattern.split(/\//);
    return fragments.reduce(
      function (route, fragment, index, fragments) {
        if(fragment.match(/^\:/)) {
          fragment.replace(/^\:/, '');
          route.tokens.push(fragment);
          route.fragments.push('([a-zA-Z0-9-_~\\.%@]+)');
        } else {
          route.fragments.push(fragment);
        }

        if(index === (fragments.length - 1)) route.regexp = route.compileRegExp();
        return route;
      },
      {
        fragments     : [],
        tokens        : [],
        compileRegExp : function () { return new RegExp(this.fragments.join("\\/")); },
        regexp        : ''
      }
    );
  },
  add : function (method, pattern, callback) {
    var route = this.compilePattern(pattern);

    route.method   = method;
    route.pattern  = route.regexp;
    route.callback = callback;

    this.routes.push(route);
    return this;
  },
  "get"    : function (pattern, callback) { return this.add('get', pattern, callback);    },
  "post"   : function (pattern, callback) { return this.add('post', pattern, callback);   },
  "put"    : function (pattern, callback) { return this.add('put', pattern, callback);    },
  "delete" : function (pattern, callback) { return this.add('delete', pattern, callback); },
  parseParameters : function (request) {
    // var uriOptions = 
  },
  find : function (method, url) {
    var routes = this.routes.filter(function (route) {
      return (route.method === method && url.match(route.pattern));
    });
    return routes[0];
  },
  parseValues : function (url, route) {
    var tokenLength = route.tokens.length + 1;
    var matches     = url.match(route.pattern);
    var values      = matches.slice(1, tokenLength);
    return route.tokens.reduce(function (finalValues, token, index, tokens) {
      finalValues[token] = values[index];
      return finalValues;
    }, {});
  },
  attachJson : function (response) {
    response.json = function (data) {
      response.end(JSON.stringify(data));
    };
    return response;
  },
  process : function (request, response) {
    console.log('[coapRouter] processing request for', request.method, request.url);

    coapRouter.attachJson(response);

    var method    = request.method ? request.method.toLowerCase() : 'get',
        url       = request.url;

    var route     = coapRouter.find(method, url);
    
    if(route) {
      var callback  = route.callback,
          values    = coapRouter.parseValues(url, route);

      _.extend(request, values);

      callback.apply(callback, [request, response]);
    } else {
      console.log('[coapRouter] no route found for', request.method, request.url);
      response.statusCode = '404';
      response.end("We could not find that resource");
    }
  }
};

module.exports = coapRouter;
