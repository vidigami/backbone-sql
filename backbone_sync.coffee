util = require 'util'
URL = require 'url'
_ = require 'underscore'
Queue = require 'queue-async'

inflection = require 'inflection'
Sequelize = require 'sequelize'
SequelizeCursor = require './lib/sequelize_cursor'
SchemaParser = require './lib/schema_parser'
RelationParser = require './lib/relation_parser'

CLASS_METHODS = [
  'initialize'
  'cursor', 'find'
  'count', 'all', 'destroy'
  # 'findOneNearDate'
]

module.exports = class SequelizeSync

  constructor: (@model_type, options={}) ->
    throw new Error("Missing url for model") unless @url = _.result((new @model_type()), 'url')
    url_parts = URL.parse(@url)
    database_parts = url_parts.pathname.split('/')
    @database = database_parts[1]
    @table = database_parts[2]
    @model_name = inflection.classify(inflection.singularize(@table))

    schema_info = SchemaParser.parse(_.result(@model_type, 'schema') or {})
    @schema = schema_info.schema
    @raw_relations = schema_info.raw_relations
    @field_options = schema_info.field_options

    url_parts.pathname = @database # remove the table from the connection
    @sequelize = new Sequelize(URL.format(url_parts), {dialect: 'mysql'})
    @connection = @sequelize.define @model_name, @schema, {freezeTableName: true, tableName: @table, underscored: true, charset: 'utf8', timestamps: false}
    @model_type._sequelize_schema = @connection

    @backbone_adapter = require './lib/sequelize_backbone_adapter'
    @model_type[fn] = _.bind(@[fn], @) for fn in CLASS_METHODS # publish methods on the model class

  initialize: =>
    @relations = RelationParser.parse(@model_type, @raw_relations)
    for relation_name, relation_info of @relations
      @connection[relation_info.type](relation_info.model._sequelize_schema, relation_info.options)

  ###################################
  # Classic Backbone Sync
  ###################################
  read: (model, options) ->
    # a collection
    if model.models
      @cursor().toJSON (err, json) ->
        return options.error?(err) if err
        options.success?(json)

    # a model
    else
      @cursor(model.get('id')).limit(1).toJSON (err, json) ->
        return options.error?(err) if err
        return options.error?(new Error "Model not found. Id #{model.get('id')}") if json.length isnt 1
        options.success?(json)

  create: (model, options) ->
    console.log "CREATE";
    @connection.create(model.attributes)
      .error (err) -> options.error?(err)
      .success (seq_model) => console.log "CREATE SUCCESS"; options.success?(@backbone_adapter.sequelizeToModel(seq_model, @model_type))

  update: (model, options) =>
    json = @backbone_adapter.attributesToNative(model.toJSON()); delete json.id
    @connection.update(json, @backbone_adapter.modelFindQuery(model))
      .error(callback)
      .success -> callback(null, model)

  delete: (model, options) ->
    @connection.remove(@backbone_adapter.modelFindQuery(model))
      .error (err) -> options.error?(err)
      .success -> options.success?()

  ###################################
  # Collection Extensions
  ###################################
  cursor: (query={}) -> return new SequelizeCursor(@, query)

  find: (query, callback) ->
    [query, callback] = [{}, query] if arguments.length is 1
    @cursor(query).toModels(callback)

  ###################################
  # Convenience Functions
  ###################################
  all: (callback) -> @cursor({}).toModels callback

  count: (query, callback) ->
    [query, callback] = [{}, query] if arguments.length is 1
    @cursor(query).count(callback)

  destroy: (query, callback) ->
    [query, callback] = [{}, query] if arguments.length is 1
    @connection.destroy(query).error(callback).success(callback)

# options
#   database_config - the database config
#   collection - the collection to use for models
#   model - the model that will be used to add query functions to
module.exports = (model_type, options) ->
  sync = new SequelizeSync(model_type, options)
  model_type.initialize = sync.initialize
  model_type._sync = sync # used for inflection
  return (method, model, options={}) -> sync[method](model, options)