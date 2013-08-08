_ = require 'underscore'
util = require 'util'
When = require 'when'
WhenNodeFn = require 'when/node/function'
Queue = require 'queue-async'
URL = require 'url'
inflection = require 'inflection'

Schema = require 'backbone-orm/lib/schema'
Utils = require 'backbone-orm/lib/utils'

SqlCursor = require './lib/sql_cursor'

module.exports = class SqlSync

  constructor: (@model_type, options={}) ->
    # set up model name
    unless @model_type.model_name # model_name can be manually set
      throw new Error("Missing url for model") unless url = _.result(@model_type.prototype, 'url')
      @model_type.model_name = Utils.parseUrl(url).model_name
    throw new Error('Missing model_name for model') unless @model_type.model_name

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
    @cursor(model.id).toJSON (err, json) ->
      return options.error(model, err) if err
      return options.error(new Error "Model not found. Id #{model.id}") if not json
      options.success(json)

  create: (model, options) =>
    json = model.toJSON()
    @connection(@model_type._table).insert(json).exec (err, res) =>
      return options.error(model, err) if err
      return options.error(new Error("Failed to create model with attributes: #{util.inspect(model.attributes)}")) unless res?.length
      json.id = res[0]
      options.success(json)

  update: (model, options) =>
    json = model.toJSON()
    @connection(@model_type._table).where('id', model.id).update(json).exec (err, res) ->
      return options.error(model, err) if err
      options.success(json)

  delete: (model, options) =>
    @connection(@model_type._table).where('id', model.id).del().exec (err, res) ->
      return options.error(model, err) if err
      options.success()

  ###################################
  # Backbone ORM - Class Extensions
  ###################################
  resetSchema: (options, callback) ->
    join_tables = []

    # TODO: connection should be obtained through a callback, not internal knowledge
    @model_type._connection.Schema.dropTableIfExists(@model_type._table)
      .then(=> @model_type._connection.Schema.createTable @model_type._table, (table) =>
        schema = @model_type.schema()
        console.log "Creating table: #{@model_type._table} with fields: \'#{_.keys(schema.fields).join(', ')}\' and relations: \'#{_.keys(schema.relations).join(', ')}\'" if options.verbose

        table.increments('id').primary()
        for key, field of schema.fields
          method = "#{field.type[0].toLowerCase()}#{field.type.slice(1)}"
          table[method](key).nullable()

        for key, relation of schema.relations
          if relation.type is 'belongsTo'
            table.integer(relation.foreign_key).nullable()
          else if relation.type is 'hasMany' and relation.reverse_relation.type is 'hasMany'
            do (relation) ->
              join_tables.push(WhenNodeFn.call((callback) -> Utils.findOrGenerateJoinTable(relation).resetSchema(callback)))
        return
      )
      .then(-> When.all(join_tables))
      .then((-> callback()), callback)

  cursor: (query={}) -> return new SqlCursor(query, _.pick(@, ['model_type', 'connection', 'backbone_adapter']))

  # TODO: query
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
    @schema.initialize()

module.exports = (model_type) ->
  sync = new SqlSync(model_type)

  model_type::sync = sync_fn = (method, model, options={}) -> # save for access by model extensions
    sync.initialize()
    return module.exports.apply(null, Array::slice.call(arguments, 1)) if method is 'createSync' # create a new sync
    return sync if method is 'sync'
    return sync.schema if method is 'schema'
    return if sync[method] then sync[method].apply(sync, Array::slice.call(arguments, 1)) else undefined

  require('backbone-orm/lib/model_extensions')(model_type) # mixin extensions
  return require('backbone-orm/lib/cache').configureSync(model_type, sync_fn)
