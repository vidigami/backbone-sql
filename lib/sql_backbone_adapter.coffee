util = require 'util'
inflection = require 'inflection'
_ = require 'underscore'

module.exports = class SqlBackboneAdapter
  @nativeToAttributes: (json, schema) ->
    for key of json
      json[key] = !!json[key] if json[key] isnt null and schema.fields[key] and schema.fields[key].type is 'Boolean'
    return json
