_ = require 'underscore'
Sequelize = require 'sequelize'

module.exports = class SchemaParser

  @db_types:
    'String': Sequelize.STRING
    'Date': Sequelize.DATE
    'Boolean': Sequelize.BOOLEAN
    'Integer': Sequelize.INTEGER
    'Float': Sequelize.FLOAT

  @parse: (schema_definition) ->
    result =
      schema: {}
      raw_relations: {}
      field_options: {}
    for key, field_options of schema_definition
      if _.isArray(field_options)
        field = field_options[0]
        options = _.reduce(field_options.slice(1), ((k,v) -> _.extend(k, v)), {})
      else
        field = field_options
        options = null
      if type = SchemaParser.db_types[field]
        result.schema[key] = type
        result.field_options[key] = options if options
      else
        result.raw_relations[key] = field_options
    return result
