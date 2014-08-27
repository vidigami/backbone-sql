###
  backbone-sql.js 0.6.4
  Copyright (c) 2013 Vidigami - https://github.com/vidigami/backbone-sql
  License: MIT (http://www.opensource.org/licenses/mit-license.php)
###

{_} = require 'backbone-orm'

module.exports = class SqlBackboneAdapter
  @nativeToAttributes: (json, schema) ->
    for key of json
      json[key] = !!json[key] if json[key] isnt null and schema.fields[key] and schema.fields[key].type is 'Boolean'
    return json
