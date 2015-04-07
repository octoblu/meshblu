var os = require('os');
var _ = require('lodash');

var appdynamics;

try {
  appdynamics = require('appdynamics');
} catch (error) {
  appdynamics = {profile: _.noop};
}
appdynamics.profile({
  controllerHostName: process.env.APP_DYNAMICS_HOST_NAME,
  controllerPort: process.env.APP_DYNAMICS_PORT,
  accountName: process.env.APP_DYNAMICS_ACCOUNT_NAME,
  accountAccessKey: process.env.APP_DYNAMICS_KEY,
  applicationName: process.env.APP_DYNAMICS_APPLICATION_NAME,
  tierName: process.env.APP_DYNAMICS_TIER_NAME,
  nodeName: os.hostname()
});
