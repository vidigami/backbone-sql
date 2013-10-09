util = require 'util'
_ = require 'underscore'
Backbone = require 'backbone'
URL = require 'url'
inflection = require 'inflection'
Queue = require 'queue-async'

SqlCursor = require './lib/sql_cursor'
DatabaseTools = require './lib/db_tools'
Schema = require 'backbone-orm/lib/schema'
Utils = require 'backbone-orm/lib/utils'
QueryCache = require 'backbone-orm/lib/query_cache'
bbCallback = Utils.bbCallback

DESTROY_BATCH_LIMIT = 1000

module.exports = class SqlSync

  constructor: (@model_type, options={}) ->
    @model_type.model_name = Utils.findOrGenerateModelName(@model_type)
    @schema = new Schema(@model_type)
    @backbone_adapter = require './lib/sql_backbone_adapter'

  initialize: ->
    return if @is_initialized; @is_initialized = true

    @schema.initialize()
    throw new Error("Missing url for model") unless url = _.result(@model_type.prototype, 'url')
    @connect(url)

  db: => @db_tools or= new DatabaseTools(@connection, @table, @schema)

  ###################################
  # Classic Backbone Sync
  ###################################
  read: (model, options) ->
    # a collection
    if model.models
      @cursor().toJSON (err, json) ->
        return options.error(err) if err
        return options.error(new Error 'Collection not fetched') if not json
        options.success?(json)
    # a model
    else
      @cursor(model.id).toJSON (err, json) ->
        return options.error(err) if err
        return options.error(new Error "Model not found. Id #{model.id}") if not json
        options.success(json)

  create: (model, options) =>
    json = model.toJSON()
    @connection(@table).insert(json, 'id').exec (err, res) =>
      return options.error(err) if err
      return options.error(new Error("Failed to create model with attributes: #{util.inspect(model.attributes)}")) unless res?.length
      QueryCache.reset(@model_type)
      json.id = res[0]
      options.success(json)

  update: (model, options) =>
    json = model.toJSON()
    @connection(@table).where('id', model.id).update(json).exec (err, res) ->
      return options.error(err) if err
      QueryCache.reset(@model_type)
      options.success(json)

  delete: (model, options) =>
    @connection(@table).where('id', model.id).del().exec (err, res) ->
      return options.error(err) if err
      QueryCache.reset(@model_type)
      options.success()

  ###################################
  # Backbone ORM - Class Extensions
  ###################################
  resetSchema: (options, callback) -> @db().resetSchema(options, callback)

  cursor: (query={}) -> return new SqlCursor(query, _.pick(@, ['model_type', 'connection', 'backbone_adapter']))

  destroy: (query, callback) ->
    @model_type.batch query, {$limit: DESTROY_BATCH_LIMIT, method: 'toJSON'}, callback, (model_json, callback) =>
      Utils.patchRemoveByJSON @model_type, model_json, (err) =>
        return callback(err) if err
        @connection(@table).where('id', model_json.id).del().exec (err) =>
          QueryCache.reset(@model_type)
          callback(err)

  ###################################
  # Backbone SQL Sync - Custom Extensions
  ###################################
  connect: (url) ->
    return if @connection and @connection.url is url
    url_parts = Utils.parseUrl(url)
    @model_type._connection = @connection = require('./lib/knex_connection').get(url_parts)

    @table = url_parts.table
    @schema.initialize()

module.exports = (type) ->
  if (new type()) instanceof Backbone.Collection # collection
    model_type = Utils.configureCollectionModelType(type, module.exports)
    return type::sync = model_type::sync

  sync = new SqlSync(type)
  type::sync = sync_fn = (method, model, options={}) -> # save for access by model extensions
    sync.initialize()
    return module.exports.apply(null, Array::slice.call(arguments, 1)) if method is 'createSync' # create a new sync
    return sync if method is 'sync'
    return sync.db() if method is 'db'
    return sync.schema if method is 'schema'
    return false if method is 'isRemote'
    return sync.table if method is 'tableName'
    return if sync[method] then sync[method].apply(sync, Array::slice.call(arguments, 1)) else undefined

  require('backbone-orm/lib/model_extensions')(type) # mixin extensions
  return require('backbone-orm/lib/cache').configureSync(type, sync_fn)
