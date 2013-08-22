util = require 'util'
inflection = require 'inflection'
_ = require 'underscore'

module.exports = class SqlBackboneAdapter
  @nativeToAttributes: (json, schema) ->
    for key of json
      json[key] = !!json[key] if schema.fields[key] and schema.fields[key].type is 'Boolean'
    return json
