###
  backbone-sql.js 0.6.5
  Copyright (c) 2013 Vidigami - https://github.com/vidigami/backbone-sql
  License: MIT (http://www.opensource.org/licenses/mit-license.php)
###

{_, Backbone} = BackboneORM = require 'backbone-orm'

module.exports = BackboneSQL = require './core' # avoid circular dependencies
publish =
  configure: require './lib/configure'
  sync: require './sync'

  _: _
  Backbone: Backbone
publish._.extend(BackboneSQL, publish)

# re-expose modules
BackboneSQL.modules = {'backbone-orm': BackboneORM}
BackboneSQL.modules[key] = value for key, value of BackboneORM.modules
