util = require 'util'
_ = require 'underscore'

# TODO: handle relationship mapping
module.exports = class SequelizeBackboneAdapter
  @nativeToAttributes: (json, schema) ->
    # for key of json
    #   if schema.fields[key] and schema.fields[key].type is 'Boolean'
    #     json[key] = !!json[key]
    return json

  @attributesToNative: (attributes, schema) ->
    for key, value of attributes
      # if schema.fields[key] and schema.fields[key].type is 'Boolean'
      #   attributes[key] = if !!value then 1 else 0
      if value and value.$in
        attributes[key] = value.$in
    return attributes
