_ = require 'underscore'
Knex = require 'knex'
Queue = require 'backbone-orm/lib/queue'

module.exports = class DatabaseTools

  constructor: (@connection, @table_name, @schema) ->
    @join_table_operations = []
    @reset()

  reset: =>
    @promise = @table = null
    return @

  end: (callback) =>
    return callback(new Error('end() called with no operations in progress, call createTable or editTable first')) unless @promise
    @promise.exec (err) =>
      # Always reset state
      @reset()
      return callback(err) if err
      if @join_table_operations.length
        queue = new Queue(1)
        for join_table_fn in @join_table_operations
          do (join_table_fn) => queue.defer (callback) =>
            join_table_fn(callback)
        queue.await (err) => @join_table_operations = []; callback(err)
      else
        callback()

  # Create and edit table methods create a knex table instance and promise
  # Operations are carried out (ie the promise is resolved) when end() is called
  createTable: =>
    throw Error("Table operation on #{@table_name} already in progress, call end() first") if @promise or @table
    @promise = @connection.knex().schema.createTable(@table_name, (t) => @table = t)
    return @

  editTable: =>
    throw Error("Table operation on #{@table_name} already in progress, call end() first") if @promise or @table
    @promise = @connection.knex().schema.table(@table_name, (t) => @table = t)
    return @

  addField: (key, field) =>
    @editTable() unless @table
    type = "#{field.type[0].toLowerCase()}#{field.type.slice(1)}"
    options = ['nullable']
    options.push('index') if field.indexed
    options.push('unique') if field.unique
    @addColumn(key, type, options)
    return @

  addColumn: (key, type, options={}) =>
    @editTable() unless @table
    column = @table[type](key)
    column[method]() for method in options
    return @

  addRelation: (key, relation) =>
    @editTable() unless @table
    return if relation.isVirtual() # skip virtual
    if relation.type is 'belongsTo'
      @addColumn(relation.foreign_key, 'integer', ['nullable', 'index'])
    else if relation.type is 'hasMany' and relation.reverse_relation.type is 'hasMany'
      @join_table_operations.push((callback) -> relation.findOrGenerateJoinTable().db().ensureSchema(callback))
    return @

  resetRelation: (key, relation) =>
    @editTable() unless @table
    return if relation.isVirtual() # skip virtual
    if relation.type is 'belongsTo'
      @addColumn(relation.foreign_key, 'integer', ['nullable', 'index'])
    else if relation.type is 'hasMany' and relation.reverse_relation.type is 'hasMany'
      @join_table_operations.push((callback) -> relation.findOrGenerateJoinTable().resetSchema(callback))
    return @

  resetSchema: (options, callback) =>
    (callback = options; options = {}) if arguments.length is 1

    @connection.knex().schema.dropTableIfExists(@table_name).exec (err) =>
      return callback(err) if err

      @createTable()
      console.log "Creating table: #{@table_name} with fields: '#{_.keys(@schema.fields).join(', ')}' and relations: '#{_.keys(@schema.relations).join(', ')}'" if options.verbose

      @addColumn('id', 'increments', ['primary'])
      @addField(key, field) for key, field of @schema.fields
      @resetRelation(key, relation) for key, relation of @schema.relations

      @end(callback)

  ensureSchema: (options, callback) =>
    (callback = options; options = {}) if arguments.length is 1

    @hasTable (err, has_table) =>
      return callback(err) if err

      if has_table
        @editTable()
      else
        @createTable()

      console.log "Ensuring table: #{@table_name} with fields: '#{_.keys(@schema.fields).join(', ')}' and relations: '#{_.keys(@schema.relations).join(', ')}'" if options.verbose

      queue = new Queue(1)
      queue.defer (callback) => @ensureColumn('id', 'increments', ['primary'], callback)

      for key, field of @schema.fields
        do (key, field) => queue.defer (callback) =>
          @ensureField(key, field, callback)

      for key, relation of @schema.relations
        do (key, relation) => queue.defer (callback) =>
          @ensureRelation(key, relation, callback)

      queue.await (err) =>
        return callback(err) if err
        @end(callback)

  ensureRelation: (key, relation, callback) =>
    if relation.type is 'belongsTo'
      @hasColumn relation.foreign_key, (err, has_column) =>
        return callback(err) if err
        @addRelation(key, relation) unless has_column
        callback()
    else if relation.type is 'hasMany' and relation.reverse_relation.type is 'hasMany'
      relation.findOrGenerateJoinTable().db().ensureSchema(callback)

  ensureField: (key, field, callback) =>
    @hasColumn key, (err, has_column) =>
      return callback(err) if err
      @addField(key, field) unless has_column
      callback()

  ensureColumn: (key, type, options, callback) =>
    @editTable() unless @table
    @hasColumn key, (err, has_column) =>
      return callback(err) if err
      @addColumn(key, type, options) unless has_column
      callback()

  # knex method wrappers
  hasColumn: (column, callback) => @connection.knex().schema.hasColumn(@table_name, column).exec callback
  hasTable: (callback) => @connection.knex().schema.hasTable(@table_name).exec callback
  dropTable: (callback) => @connection.knex().schema.dropTable(@table_name).exec callback
  dropTableIfExists: (callback) => @connection.knex().schema.dropTableIfExists(@table_name).exec callback
  renameTable: (to, callback) => @connection.knex().schema.renameTable(@table_name, to).exec callback
