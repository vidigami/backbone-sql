util = require 'util'
URL = require 'url'
_ = require 'underscore'
Queue = require 'queue-async'

inflection = require 'inflection'
Sequelize = require 'sequelize'

Schema = require 'backbone-orm/lib/schema'
sequelize_types = require './lib/sequelize_types'
SequelizeCursor = require './lib/sequelize_cursor'
Utils = require 'backbone-orm/utils'

module.exports = class SequelizeBackboneSync

  constructor: (@model_type, options={}) ->
    throw new Error("Missing url for model") unless url = _.result(@model_type.prototype, 'url')
    url_parts = URL.parse(url)
    database_parts = url_parts.pathname.split('/')
    @database = database_parts[1]
    @table = database_parts[2]
    url_parts.pathname = @database # remove the table from the connection

    # publish methods and sync on model
    @model_type.model_name = Utils.urlToModelName(url)
    @model_type._sync = @
    @model_type._schema = new Schema(@model_type, sequelize_types)

    @sequelize = new Sequelize(URL.format(url_parts), {dialect: 'mysql', logging: false})
    @connection = @sequelize.define @model_name, @model_type._schema.fields, {freezeTableName: true, tableName: @table, underscored: true, charset: 'utf8', timestamps: false}

    @backbone_adapter = require './lib/sequelize_backbone_adapter'

  initialize: ->
    return if @is_initialized
    @is_initialized = true
    @model_type._schema.initialize()

    @relations = @model_type._schema.relations
    for name, relation_info of @relations
      @connection[relation_info.type](relation_info.reverse_model_type._sync.connection, _.extend({ as: name, foreignKey: relation_info.foreign_key }, relation_info.options))

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

  create: (model, options) ->
    json = model.toJSON()
    # Clear relations for the query
    delete json[name] for name, relation_info of @relations when json[name]
    @connection.create(json)
      .success (seq_model) =>
        return options.error(new Error("Failed to create model with attributes: #{util.inspect(model.attributes)}")) unless seq_model
        options.success?(@backbone_adapter.nativeToAttributes(seq_model))

  update: (model, options) =>
    json = model.toJSON()
    # Clear relations for the query
    delete json[name] for name, relation_info of @relations when json[name]
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

module.exports = (model_type, cache) ->
  sync = new SequelizeBackboneSync(model_type)

  sync_fn = (method, model, options={}) ->
    sync['initialize']()
    sync[method].apply(sync, Array::slice.call(arguments, 1))

  require('backbone-orm/lib/model_extensions')(model_type, sync_fn) # mixin extensions
  return if cache then require('backbone-orm/cache_sync')(model_type, sync_fn) else sync_fn