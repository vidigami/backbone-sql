_ = require 'underscore'
util = require 'util'
Queue = require 'queue-async'
URL = require 'url'
inflection = require 'inflection'

Schema = require 'backbone-orm/lib/schema'
Utils = require 'backbone-orm/lib/utils'

SqlCursor = require './lib/sql_cursor'

module.exports = class SqlSync

  constructor: (@model_type, options={}) ->
    @schema = new Schema(@model_type)
    @backbone_adapter = require './lib/sql_backbone_adapter'

  initialize: ->
    return if @is_initialized; @is_initialized = true

    throw new Error("Missing url for model") unless url = _.result(@model_type.prototype, 'url')

    # publish methods and sync on model
    @model_type.model_name = Utils.parseUrl(url).model_name unless @model_type.model_name # model_name can be manually set
    throw new Error('Missing model_name for model') unless @model_type.model_name

    @connect(url)

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
    @connection(@model_type._table).insert(json).exec (err, res) =>
      return options.error(err) if err
      return options.error(new Error("Failed to create model with attributes: #{util.inspect(model.attributes)}")) unless res?.length
      json.id = res[0]
      options.success?(json)

  update: (model, options) =>
    json = model.toJSON()
    @connection(@model_type._table).where('id', model.get('id')).update(json).exec (err, res) ->
      return options.error(err) if err
      options.success?(res[0] if res.length)

  delete: (model, options) =>
    @connection(@model_type._table).where('id', model.get('id')).del().exec (err, res) ->
      return options.error(err) if err
      options.success?(model, {}, options)

  ###################################
  # Backbone ORM - Class Extensions
  ###################################
  cursor: (query={}) -> return new SqlCursor(query, _.pick(@, ['model_type', 'connection', 'backbone_adapter']))

  #todo: query
  destroy: (query, callback) ->
    builder = @connection(@model_type._table)
    builder.where('id', query) unless _.isObject(query)
    builder.del().exec callback

  ###################################
  # Backbone SQL Sync - Custom Extensions
  ###################################
  connect: (url) ->
    return if @connection and @connection.url is url
    url_parts = Utils.parseUrl(url)
    @model_type._connection = @connection = require('./lib/knex_connection').get(url_parts)

#    sequelize_timestamps = @schema.fields.created_at and @schema.fields.updated_at
    @model_type._table = url_parts.table
    @model_type._relations = @schema.relations
    @model_type._fields = @schema.fields

    @schema.initialize()

module.exports = (model_type, cache) ->
  sync = new SqlSync(model_type)

  model_type::sync = sync_fn = (method, model, options={}) -> # save for access by model extensions
    sync.initialize()
    return module.exports.apply(null, Array::slice.call(arguments, 1)) if method is 'createSync' # create a new sync
    return sync if method is 'sync'
    return sync.schema if method is 'schema'
    if sync[method] then sync[method].apply(sync, Array::slice.call(arguments, 1)) else return undefined

  require('backbone-orm/lib/model_extensions')(model_type) # mixin extensions
  return if cache then require('backbone-orm/lib/cache_sync')(model_type, sync_fn) else sync_fn
