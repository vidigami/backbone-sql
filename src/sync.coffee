###
  backbone-sql.js 0.5.10
  Copyright (c) 2013 Vidigami - https://github.com/vidigami/backbone-sql
  License: MIT (http://www.opensource.org/licenses/mit-license.php)
###

util = require 'util'
_ = require 'underscore'
Backbone = require 'backbone'
inflection = require 'inflection'

Queue = require 'backbone-orm/lib/queue'
DatabaseURL = require 'backbone-orm/lib/database_url'
Schema = require 'backbone-orm/lib/schema'
Utils = require 'backbone-orm/lib/utils'
ModelCache = require('backbone-orm/lib/cache/singletons').ModelCache
QueryCache = require('backbone-orm/lib/cache/singletons').QueryCache
ModelTypeID = require('backbone-orm/lib/cache/singletons').ModelTypeID
modelExtensions = require 'backbone-orm/lib/extensions/model'

Connection = require './connection'
SqlCursor = require './cursor'
DatabaseTools = require './database_tools'

DESTROY_BATCH_LIMIT = 1000

class SqlSync

  constructor: (@model_type, options={}) ->
    @[key] = value for key, value of options
    @model_type.model_name = Utils.findOrGenerateModelName(@model_type)
    @model_type.model_id = ModelTypeID.generate(@model_type)
    @schema = new Schema(@model_type)
    @backbone_adapter = require './backbone_adapter'

  ###################################
  # Classic Backbone Sync
  ###################################
  read: (model, options) ->
    # a collection
    if model.models
      @cursor().toJSON (err, json) =>
        return options.error(err) if err
        return options.error(new Error 'Collection not fetched') if not json
        options.success?(json)
      # a model
    else
      @cursor(model.id).toJSON (err, json) =>
        return options.error(err) if err
        return options.error(new Error "Model not found. Id #{model.id}") if not json
        options.success(json)

  create: (model, options) =>
    json = model.toJSON()
    @getTable('master').insert(json, 'id').exec (err, res) =>
      return options.error(err) if err
      return options.error(new Error("Failed to create model with attributes: #{util.inspect(model.attributes)}")) unless res?.length
      QueryCache.reset @model_type, (err) =>
        return options.error?(err) if err
        json.id = res[0]
        options.success(json)

  update: (model, options) =>
    json = model.toJSON()
    @getTable('master').where('id', model.id).update(json).exec (err, res) =>
      return options.error(err) if err
      QueryCache.reset @model_type, (err) =>
        return options.error?(err) if err
        options.success(json)

  delete: (model, options) =>
    @getTable('master').where('id', model.id).del().exec (err, res) =>
      return options.error(err) if err
      QueryCache.reset @model_type, (err) =>
        return options.error?(err) if err
        options.success()

  ###################################
  # Backbone ORM - Class Extensions
  ###################################
  resetSchema: (options, callback) -> @db().resetSchema(options, callback)

  cursor: (query={}) ->
    options = _.pick(@, ['model_type', 'backbone_adapter'])
    options.connection = @getConnection()
    return new SqlCursor(query, options)

  destroy: (query, callback) ->
    [query, callback] = [{}, query] if arguments.length is 1

    @model_type.each _.extend({$each: {limit: DESTROY_BATCH_LIMIT, json: true}}, query),
      ((model_json, callback) =>
        Utils.patchRemoveByJSON @model_type, model_json, (err) =>
          return callback(err) if err
          @getTable('master').where('id', model_json.id).del().exec (err) =>
            return callback(err) if err
            QueryCache.reset @model_type, callback
      ), callback

  ###################################
  # Backbone SQL Sync - Custom Extensions
  ###################################
  initialize: ->
    return if @is_initialized; @is_initialized = true

    @schema.initialize()
    throw new Error("Missing url for model") unless url = _.result(new @model_type, 'url')
    @connect(url)

  connect: (url) ->
    @table = (new DatabaseURL(url)).table
    @connections or= {all: [], master: new Connection(url), slaves: []}

    if @slaves?.length
      @connections.slaves.push(connection = new Connection("#{slave_url}/#{@table}")) for slave_url in @slaves

    # cache all connections
    @connections.all = [@connections.master].concat(@connections.slaves)
    @schema.initialize()

  # Get the knex table instance for a db_type
  getTable: (db_type) => @getConnection(db_type)(@table)

  # Return the master db connection if db_type is 'master' or a random one otherwise
  getConnection: (db_type) =>
    return @connections.master.knex() if db_type is 'master' or @connections.all.length is 1
    return @connections.all[~~(Math.random() * (@connections.all.length))].knex()

  db: => @db_tools or= new DatabaseTools(@connections.master, @table, @schema)

module.exports = (type, options) ->
  if Utils.isCollection(new type()) # collection
    model_type = Utils.configureCollectionModelType(type, module.exports)
    return type::sync = model_type::sync

  sync = new SqlSync(type, options)
  type::sync = sync_fn = (method, model, options={}) -> # save for access by model extensions
    sync.initialize()
    return module.exports.apply(null, Array::slice.call(arguments, 1)) if method is 'createSync' # create a new sync
    return sync if method is 'sync'
    return sync.db() if method is 'db'
    return sync.schema if method is 'schema'
    return false if method is 'isRemote'
    return sync.table if method is 'tableName'
    return if sync[method] then sync[method].apply(sync, Array::slice.call(arguments, 1)) else undefined

  modelExtensions(type)
  return ModelCache.configureSync(type, sync_fn)
