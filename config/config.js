var path = require('path'),
    root = path.normalize(__dirname + '/..');

module.exports = {

  'development': {
    port: 3000,
    root: root,
    debug: false,
  },
  
  'test': {
    port: 3000,
    root: root,
    debug: false
  },

  'production': {
    port: 443, //TODO: 443 at some point
    root: root,
    debug: false,
  }

};
