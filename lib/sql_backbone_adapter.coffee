util = require 'util'
inflection = require 'inflection'
_ = require 'underscore'

# TODO: handle relationship mapping
module.exports = class SqlBackboneAdapter
  @nativeToAttributes: (json, schema, include) ->
    for key of json
      if schema.fields[key] and schema.fields[key].type is 'Boolean'
        json[key] = !!json[key]


    return json
