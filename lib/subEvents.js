var events = require('events');

var subEvents = new events.EventEmitter();

//theoretically possible for every connected port to simultaenously subscribe to same topic
subEvents.setMaxListeners(65000);

module.exports = subEvents;
