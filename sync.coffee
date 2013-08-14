util = require 'util'
_ = require 'underscore'
Backbone = require 'backbone'
URL = require 'url'
inflection = require 'inflection'
Queue = require 'queue-async'

When = require 'when'
WhenNodeFn = require 'when/node/function'

SqlCursor = require './lib/sql_cursor'
Schema = require 'backbone-orm/lib/schema'
Utils = require 'backbone-orm/lib/utils'
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
        return options.error(model, err) if err
        return options.error(new Error "Model not found. Id #{model.id}") if not json
        options.success(json)

  create: (model, options) =>
    json = model.toJSON()
    @connection(@table).insert(json).exec (err, res) =>
      return options.error(model, err) if err
      return options.error(new Error("Failed to create model with attributes: #{util.inspect(model.attributes)}")) unless res?.length
      json.id = res[0]
      options.success(json)

  update: (model, options) =>
    json = model.toJSON()
    @connection(@table).where('id', model.id).update(json).exec (err, res) ->
      return options.error(model, err) if err
      options.success(json)

  delete: (model, options) =>
    @connection(@table).where('id', model.id).del().exec (err, res) ->
      return options.error(model, err) if err
      options.success()

  ###################################
  # Backbone ORM - Class Extensions
  ###################################
  resetSchema: (options, callback) ->
    join_tables = []

    # TODO: connection should be obtained through a callback, not internal knowledge
    @model_type._connection.Schema.dropTableIfExists(@table)
      .then(=> @model_type._connection.Schema.createTable @table, (table) =>
        schema = @model_type.schema()
        console.log "Creating table: #{@table} with fields: \'#{_.keys(schema.fields).join(', ')}\' and relations: \'#{_.keys(schema.relations).join(', ')}\'" if options.verbose

        table.increments('id').primary()
        for key, field of schema.fields
          method = "#{field.type[0].toLowerCase()}#{field.type.slice(1)}"
          table[method](key).nullable()

        for key, relation of schema.relations
          if relation.type is 'belongsTo'
            table.integer(relation.foreign_key).nullable()
          else if relation.type is 'hasMany' and relation.reverse_relation.type is 'hasMany'
            do (relation) ->
              join_tables.push(WhenNodeFn.call((callback) -> relation.findOrGenerateJoinTable().resetSchema(callback)))
        return
      )
      .then(-> When.all(join_tables))
      .then((-> callback()), callback)

  cursor: (query={}) -> return new SqlCursor(query, _.pick(@, ['model_type', 'connection', 'backbone_adapter']))

  # TODO: query
  destroy: (query, callback) ->
    @model_type.batch query, {$limit: DESTROY_BATCH_LIMIT, method: 'toJSON'}, callback, (model_json, callback) =>
      Utils.destroyRelationsByJSON @model_type, model_json, (err) =>
        return callback(err) if err
        @connection(@table).where('id', model_json.id).del().exec (err) => callback(err)

  ###################################
  # Backbone SQL Sync - Custom Extensions
  ###################################
  connect: (url) ->
    return if @connection and @connection.url is url
    url_parts = Utils.parseUrl(url)
    @model_type._connection = @connection = require('./lib/knex_connection').get(url_parts)

#    sequelize_timestamps = @schema.fields.created_at and @schema.fields.updated_at
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
    return sync.schema if method is 'schema'
    return false if method is 'isRemote'
    return sync.table if method is 'tableName'
    return if sync[method] then sync[method].apply(sync, Array::slice.call(arguments, 1)) else undefined

  require('backbone-orm/lib/model_extensions')(type) # mixin extensions
  return require('backbone-orm/lib/cache').configureSync(type, sync_fn)
