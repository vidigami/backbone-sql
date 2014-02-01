###
  backbone-sql.js 0.5.5
  Copyright (c) 2013 Vidigami - https://github.com/vidigami/backbone-sql
  License: MIT (http://www.opensource.org/licenses/mit-license.php)
###

_ = require 'underscore'
inflection = require 'inflection'
Knex = require 'knex'
Queue = require 'backbone-orm/lib/queue'
KNEX_COLUMN_OPERATORS = ['indexed', 'nullable', 'unique']
KNEX_COLUMN_OPTIONS = ['textType', 'length', 'precision', 'scale', 'value', 'values']

module.exports = class DatabaseTools

  constructor: (@connection, @table_name, @schema, options={}) ->
    @strict = options.strict ? true
    @join_table_operations = []
    @reset()

  reset: =>
    @promise = @table = null
    return @

  end: (callback) =>
    unless @promise
      return callback(new Error('end() called with no operations in progress, call createTable or editTable first')) if @strict
      return callback()
    @promise.exec (err) =>
      # Always reset state
      @reset()
      return callback(err) if err
      if @join_table_operations.length
        queue = new Queue(1)
        for join_table_fn in @join_table_operations
          do (join_table_fn) => queue.defer (callback) =>
            join_table_fn(callback)
        queue.await (err) =>
          @join_table_operations = []
          callback(err)
      else
        callback()

  # Create and edit table methods create a knex table instance and promise
  # Operations are carried out (ie the promise is resolved) when end() is called
  createTable: =>
    if @promise and @table
      throw Error("Table operation on #{@table_name} already in progress, call end() first") if @strict
      return @
    @promise = @connection.knex().schema.createTable(@table_name, (t) => @table = t)
    return @

  editTable: =>
    if @promise and @table
      throw Error("Table operation on #{@table_name} already in progress, call end() first") if @strict
      return @
    @promise = @connection.knex().schema.table(@table_name, (t) => @table = t)
    return @

  addField: (key, field) =>
    @editTable() unless @table
    type = "#{field.type[0].toLowerCase()}#{field.type.slice(1)}"
    @addColumn(key, type, field)
    return @

  addIDColumn: =>
    @addColumn('id', 'increments', ['primary'])

  addColumn: (key, type, options={}) =>
    @editTable() unless @table

    column_args = [key]

    # Assign column specific arguments
    constructor_options = _.pick(options, KNEX_COLUMN_OPTIONS)
    unless _.isEmpty(constructor_options)
      # Special case as they take two args
      if type in ['float', 'decimal']
        column_args[1] = constructor_options['precision']
        column_args[2] = constructor_options['scale']
      # Assume we've been given one valid argument
      else
        column_args[1] = _.values(constructor_options)[0]

    column = @table[type].apply(@table, column_args)

    knex_methods = []
    knex_methods.push['notNullable'] if options.nullable is false
    knex_methods.push('index') if options.indexed
    knex_methods.push('unique') if options.unique

    column[method]() for method in knex_methods

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

      @addIDColumn()
      @addField(key, field) for key, field of @schema.fields
      @resetRelation(key, relation) for key, relation of @schema.relations

      @end(callback)

  # Ensure that the schema is reflected correctly in the database
  # Will create a table and add columns as required
  # Will not remove columns
  ensureSchema: (options, callback) =>

    (callback = options; options = {}) if arguments.length is 1

    return callback() if @ensuring
    @ensuring = true

    @hasTable (err, table_exists) =>
      (@ensuring = false; return callback(err)) if err
      console.log "Ensuring table: #{@table_name} with fields: '#{_.keys(@schema.fields).join(', ')}' and relations: '#{_.keys(@schema.relations).join(', ')}'" if options.verbose

      unless table_exists
        @createTable()
        @addIDColumn()
        @end (err) =>
          (@ensuring = false; return callback(err)) if err
          return @ensureSchemaForExistingTable(options, (err) => @ensuring = false; callback(err))
      else
        return @ensureSchemaForExistingTable(options, (err) => @ensuring = false; callback(err))

  # Should only be called once the table exists - can't do column checks unless the table has been created
  # Should only be called by @ensureSchema, sets @ensuring to false when complete
  ensureSchemaForExistingTable: (options, callback) =>

    @editTable()
    queue = new Queue(1)
    queue.defer (callback) => @ensureColumn('id', 'increments', ['primary'], callback)

    if @schema.fields
      for key, field of @schema.fields
        do (key, field) => queue.defer (callback) =>
          @ensureField(key, field, callback)

    if @schema.relations
      for key, relation of @schema.relations
        do (key, relation) => queue.defer (callback) =>
          @ensureRelation(key, relation, callback)

    queue.await (err) =>
      return callback(err) if err
      @end(callback)

  ensureRelation: (key, relation, callback) =>
    if relation.type is 'belongsTo'
      @hasColumn relation.foreign_key, (err, column_exists) =>
        return callback(err) if err
        @addRelation(key, relation) unless column_exists
        callback()
    else if relation.type is 'hasMany' and relation.reverse_relation.type is 'hasMany'
      relation.findOrGenerateJoinTable().db().ensureSchema(callback)
    else
      callback()

  ensureField: (key, field, callback) =>
    @hasColumn key, (err, column_exists) =>
      return callback(err) if err
      @addField(key, field) unless column_exists
      callback()

  ensureColumn: (key, type, options, callback) =>
    @editTable() unless @table
    @hasColumn key, (err, column_exists) =>
      return callback(err) if err
      @addColumn(key, type, options) unless column_exists
      callback()

  # knex method wrappers
  hasColumn: (column, callback) => @connection.knex().schema.hasColumn(@table_name, column).exec callback
  hasTable: (callback) => @connection.knex().schema.hasTable(@table_name).exec callback
  dropTable: (callback) => @connection.knex().schema.dropTable(@table_name).exec callback
  dropTableIfExists: (callback) => @connection.knex().schema.dropTableIfExists(@table_name).exec callback
  renameTable: (to, callback) => @connection.knex().schema.renameTable(@table_name, to).exec callback
