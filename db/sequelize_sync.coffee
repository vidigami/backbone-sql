_ = require 'underscore'
log = require '../node/logger'

inflection = require 'inflection'
Sequelize = require 'sequelize'
sequelize_connection = require './connection'
SequelizeBackboneAdapter = require './sequelize_backbone_adapter'
SchemaParser = require './schema_parser'
RelationParser = require './relation_parser'

module.exports = class SequelizeSync

  constructor: (@model_type, options={}) ->
    [@db_url, @table_name, @model_name] = @_parseUrl(@model_type::url)

    @schema_parser = new SchemaParser(@model_type.schema).parse()
    @schema = @schema_parser.schema
    @raw_relations = @schema_parser.raw_relations
    @field_options = @schema_parser.field_options

    @connection = sequelize_connection.define @model_name, @schema, { freezeTableName: true, tableName: @table_name}
    @model_type.sequelize_schema = @connection

    @backbone_adapter = new SequelizeBackboneAdapter()

    @model_type.findOne = @findOne
    @model_type.find = @find
    @model_type.count = @count

    con = @connection
    @model_type.sequelizeToAttributes = -> @backbone_adapter.sequelizeToAttributes(con, @attributes)
    @model_type.attributesToSequelize = -> @backbone_adapter.attributesToSequelize(@attributes, con)
    @model_type.collection = (callback) => @connection.collection callback

  initialize: =>
    @relations = new RelationParser(@model_type, @raw_relations).parse().relations
    for relation_name, relation_info of @relations
      @connection[relation_info.type](relation_info.model.sequelize_schema, relation_info.options)

  findOne: (query, callback) =>
    @connection.find(query)
      .success (model) =>
#        console.log model.getPhotos
#        console.log model.getPhotos().success( (a) ->  console.log a; console.log arguments)
        callback null, @backbone_adapter.sequelizeToModel(model, @model_type)
      .error (err) -> callback(err)

  find: (query_args_callback) =>
    [query_args, callback] = @_extractQueryArgs(arguments)
    @connection.findAll(query_args)
      .success (models) =>
        callback null, (@backbone_adapter.sequelizeToModel(model, @model_type) for model in models)
      .error (err) -> callback(err)

  count: (optional_query, callback) =>
    [query_args, callback] = @_extractQueryArgs(arguments, true)
    @connection.count(query_args)
      .success (count) =>
        callback null, count
      .error (err) -> callback(err)

  #todo
  create: (model, callback) =>
    sequelize_model = @connection.build(model.attributes)
    sequelize_model.save
      .success (model) =>
        callback null, @backbone_adapter.sequelizeToModel(model, @model_type)
      .error (err) -> callback(err)

  update: (model, callback) =>

    # Starts to get messy here. Either hit the db for an instance of the sequelize model each save
    # or keep track of it and update it whenever the bb model changes. ew
#    if model._db_model
#      model._db_model.save
#        .then =>
#          callback null, @backbone_adapter.sequelizeToModel(model, @model_type)
#        .error (err) -> callback(err)
#    else

#    sequelize_model = @connection.find(model.id)
#      .success =>
#        sequelize_model = @backbone_adapter.attributesToSequelize(model.attributes, sequelize_model)
#        sequelize_model.save
#          .success (model) =>
#            callback null, @backbone_adapter.sequelizeToModel(model, @model_type)
#          .error (err) -> callback(err)
#      .error (err) -> callback(err)

    # Need to test if this works
    sequelize_model = @connection.build(model.attributes)
    sequelize_model.save
      .success (model) =>
        callback null, @backbone_adapter.sequelizeToModel(model, @model_type)
      .error (err) -> callback(err)

  delete: (model, callback) ->
    sequelize_model = @connection.build(model.attributes)
    sequelize_model.destroy
      .success (model) =>
        callback null
      .error (err) -> callback(err)

  _extractQueryArgs: (args, query_optional) ->
    return [[{}], args[0]] if query_optional and args.length is 1
    query_args = Array.prototype.slice.call(args)
    return [query_args, query_args.pop()]

  _parseUrl: (url) ->
    split = url.split('/')
    table = split.pop()
    return [split.join('/'), table, inflection.classify(inflection.singularize(table))]


# options
#   database_config - the database config
#   collection - the collection to use for models
#   model - the model that will be used to add query functions to
module.exports = (model_type, options) ->
  sync = new SequelizeSync(model_type, options)
  model_type.initialize = sync.initialize
  model_type._sync = sync
  return (method, model, options={}) -> sync[method](model, options)