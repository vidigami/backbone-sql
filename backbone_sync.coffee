util = require 'util'
URL = require 'url'
_ = require 'underscore'
Queue = require 'queue-async'

inflection = require 'inflection'
Sequelize = require 'sequelize'

Schema = require 'backbone-orm/lib/schema'
SequelizeCursor = require './lib/sequelize_cursor'
Utils = require 'backbone-orm/utils'

SEQUELIZE_TYPES = require './lib/sequelize_types'
SEQUELIZE_RELATIONS =
  One: require './lib/relations/one'
  Many: require './lib/relations/many'

module.exports = class SequelizeBackboneSync

  constructor: (@model_type, options={}) ->
    throw new Error("Missing url for model") unless url = _.result(@model_type.prototype, 'url')
    @url_parts = URL.parse(url)
    database_parts = @url_parts.pathname.split('/')
    @database = database_parts[1]
    @table = database_parts[2]
    @url_parts.pathname = @database # remove the table from the connection

    # publish methods and sync on model
    @model_type.model_name = Utils.urlToModelName(url)
    @model_type._sync = @
    @model_type._schema = new Schema(@model_type, SEQUELIZE_TYPES, SEQUELIZE_RELATIONS)

    @model_type::initialize = (json) ->
#      console.log '------------------'
#      console.log json
      @attributes or= {}
      for relation, relation_info of @constructor._sync.relations
#        console.log relation_info.ids_accessor
        rel = { _orm_needs_load: true }
        rel.id = json[relation_info.ids_accessor] if json[relation_info.ids_accessor]
        @attributes[relation] = rel
#      console.log @attributes
#      console.log '------------------'
      return json

    @sequelize = new Sequelize(URL.format(@url_parts), {dialect: 'mysql', logging: false})
    @connection = @sequelize.define @model_name, @model_type._schema.fields, {freezeTableName: true, tableName: @table, underscored: true, charset: 'utf8', timestamps: false}

    @backbone_adapter = require './lib/sequelize_backbone_adapter'

  initialize: ->
    return if @is_initialized
    @is_initialized = true
    @model_type._schema.initialize()

    @relations = @model_type._schema.relations
    for name, relation_info of @relations
      @connection[relation_info.type](relation_info.reverse_model_type._sync.connection, _.extend({ as: name, foreignKey: relation_info.foreign_key }, relation_info.options))

  sync: -> return @

  ###################################
  # Classic Backbone Sync
  ###################################
  read: (model, options) ->
    # a collection
    if model.models
      @cursor().toJSON (err, json) ->
        return options.error(err) if err
        options.success?(json)

    # a model
    else
      @cursor(model.get('id')).toJSON (err, json) ->
        return options.error(err) if err
        return options.error(new Error "Model not found. Id #{model.get('id')}") if not json
        options.success?(json)

  create: (model, options) =>
    @_relationsToForeignKeys(model)
    json = model.toJSON()
    @connection.create(json)
      .success (seq_model) =>
        return options.error(new Error("Failed to create model with attributes: #{util.inspect(model.attributes)}")) unless seq_model
        options.success?(@backbone_adapter.nativeToAttributes(seq_model))

  update: (model, options) =>
    @_relationsToForeignKeys(model)
    json = model.toJSON()
    @connection.update(json, model.get('id'))
      .success( -> options.success?(json))
      .error (err) -> options.error(err)

  delete: (model, options) ->
    @connection.destroy(model.get('id'))
      .success( -> options.success?(model))
      .error (err) -> options.error(err)

  ###################################
  # Backbone ORM - Class Extensions
  ###################################
  cursor: (query={}) -> return new SequelizeCursor(query, _.pick(@, ['model_type', 'connection', 'backbone_adapter']))

  destroy: (query, callback) ->
    [query, callback] = [{}, query] if arguments.length is 1
    @connection.destroy(query)
      .success(callback)
      .error(callback)

  schema: (key) -> @model_type._schema
  relation: (key) -> @model_type._schema.relation(key)

  #todo: move to a better place
  _relationsToForeignKeys: (model) =>
    for field, relation_info of @relations
      related = model.attributes[field]
      delete model.attributes[relation_info.ids_accessor]
      model.attributes[relation_info.foreign_key] = related.id if related and relation_info.type is 'belongsTo'
      delete model.attributes[field]

module.exports = (model_type, cache) ->
  sync = new SequelizeBackboneSync(model_type)

  sync_fn = (method, model, options={}) ->
    sync['initialize']()
    return module.exports.apply(null, Array::slice.call(arguments, 1)) if method is 'createSync' # create a new sync
    sync[method].apply(sync, Array::slice.call(arguments, 1))

  require('backbone-orm/lib/model_extensions')(model_type, sync_fn) # mixin extensions
  return if cache then require('backbone-orm/cache_sync')(model_type, sync_fn) else sync_fn
