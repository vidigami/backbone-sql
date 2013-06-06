_ = require 'underscore'
Sequelize = require 'sequelize'

module.exports = class SchemaParser

  constructor: (@schema_definition) ->

  db_types:
    'String': Sequelize.STRING
    'Date': Sequelize.DATE
    'Boolean': Sequelize.BOOLEAN
    'Integer': Sequelize.INTEGER
    'Float': Sequelize.FLOAT

  parse: ->
    @schema = {}
    @raw_relations = {}
    @field_options = {}
    for name, field_options of @schema_definition
      if Array.isArray(field_options)
        field = field_options[0]
        options = _.reduce(field_options.slice(1), ((k,v) -> _.extend(k, v)), {})
      else
        field = field_options
        options = null
      if @db_types[field]
        @schema[name] = @db_types[field]
        @field_options[name] = options if options
      else
        @raw_relations[name] = field_options
    return @
