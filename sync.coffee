util = require 'util'
_ = require 'underscore'
Queue = require 'queue-async'
URL = require 'url'

inflection = require 'inflection'
Sequelize = require 'sequelize'

Schema = require 'backbone-orm/lib/schema'
SequelizeCursor = require './lib/sequelize_cursor'
Utils = require 'backbone-orm/lib/utils'

SEQUELIZE_TYPES = require './lib/sequelize_types'

module.exports = class SequelizeSync

  constructor: (@model_type, options={}) ->
    throw new Error("Missing url for model") unless @url = _.result(@model_type.prototype, 'url')
    url_parts = Utils.parseUrl(@url)

    # publish methods and sync on model
    @model_type.model_name = url_parts.model_name unless @model_type.model_name # model_name can be manually set
    throw new Error('Missing model_name for model') unless @model_type.model_name
    @model_type._sync = @
    @model_type._schema = new Schema(@model_type)
    @model_type._table = url_parts.table

    sequelize_url_parts = URL.parse(@url)
    sequelize_url_parts.pathname = url_parts.database
    @sequelize = require('./lib/sequelize_connection').get(URL.format(sequelize_url_parts))

    @backbone_adapter = require './lib/sequelize_backbone_adapter'
    sequelized_fields = {}
    sequelized_fields[field] = SEQUELIZE_TYPES[options.type] for field, options of @model_type._schema.fields
    @model_type._connection = @connection = @sequelize.define @model_name, sequelized_fields, {freezeTableName: true, tableName: @model_type._table, underscored: true, charset: 'utf8', timestamps: false}

  initialize: ->
    return if @is_initialized; @is_initialized = true
    @model_type._schema.initialize()

    @relations = @model_type._schema.relations
    for name, relation_info of @relations
      # sequelize requires the 'as' property to match the tablename of the relation. todo: fix
      relation_options = _.extend({as: relation_info.reverse_model_type._table, foreignKey: relation_info.foreign_key, useJunctionTable: false}, relation_info.options)
      @connection[relation_info.type](relation_info.reverse_model_type._connection, relation_options)
    return

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
    json = model.toJSON()
    @connection.create(json)
      .success (seq_model) =>
        return options.error(new Error("Failed to create model with attributes: #{util.inspect(model.attributes)}")) unless seq_model
        options.success?(@backbone_adapter.nativeToAttributes(seq_model.values, @model_type.schema()))

  update: (model, options) =>
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
    @connection.destroy(query)
      .success(callback)
      .error(callback)

  schema: (key) -> @model_type._schema
  relation: (key) -> @model_type._schema.relation(key)

module.exports = (model_type, cache) ->
  sync = new SequelizeSync(model_type)

  sync_fn = (method, model, options={}) -> # save for access by model extensions
    sync.initialize()
    return module.exports.apply(null, Array::slice.call(arguments, 1)) if method is 'createSync' # create a new sync
    return sync if method is 'sync'
    sync[method].apply(sync, Array::slice.call(arguments, 1))

  require('backbone-orm/lib/model_extensions')(model_type) # mixin extensions
  return if cache then require('backbone-orm/lib/cache_sync')(model_type, sync_fn) else sync_fn
