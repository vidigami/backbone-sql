util = require 'util'
inflection = require 'inflection'
_ = require 'underscore'

module.exports = class SqlBackboneAdapter
  @nativeToAttributes: (json, schema) ->
    for key of json
      if schema.fields[key] and schema.fields[key].type is 'Boolean'
        json[key] = if json[key] is 1 then true else if json[key] is 0 then false else null
    return json
