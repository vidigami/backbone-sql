util = require 'util'
inflection = require 'inflection'
_ = require 'underscore'

# TODO: handle relationship mapping
module.exports = class SqlBackboneAdapter
  @nativeToAttributes: (json, schema) ->
    for key of json
      if schema.fields[key] and schema.fields[key].type is 'Boolean'
        json[key] = !!json[key]

      # hack to get around sequelize requiring table names as relation fields
#      else if not schema.relation(key) and schema.relation(single = inflection.singularize(key))
#        json[single] = json[key]
#        delete json[key]

#    console.log json
    return json
