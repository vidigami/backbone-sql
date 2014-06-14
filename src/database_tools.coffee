###
  backbone-sql.js 0.5.7
  Copyright (c) 2013 Vidigami - https://github.com/vidigami/backbone-sql
  License: MIT (http://www.opensource.org/licenses/mit-license.php)
###

_ = require 'underscore'
inflection = require 'inflection'
Knex = require 'knex'
Queue = require 'backbone-orm/lib/queue'
KNEX_COLUMN_OPERATORS = ['indexed', 'nullable', 'unique']
KNEX_COLUMN_OPTIONS = ['textType', 'length', 'precision', 'scale', 'value', 'values']

debounceCallback = (callback) ->
  return debounced_callback = -> return if debounced_callback.was_called; debounced_callback.was_called = true; callback.apply(null, Array.prototype.slice.call(arguments, 0))

module.exports = class DatabaseTools

  constructor: (@connection, @table_name, @schema, options={}) ->
    @strict = options.strict ? true
    @join_table_operations = []

  end: (callback) =>
    return callback() unless @join_table_operations.length
    queue = new Queue(1)
    for join_table_fn in @join_table_operations
      do (join_table_fn) => queue.defer (callback) => join_table_fn(callback)
    queue.await (err) =>
      @join_table_operations = []
      callback(err)

  # Create and edit table methods create a knex table instance
  createTable: (callback) =>
    throw new Error "createTable requires a callback" unless _.isFunction(callback)

    callback = debounceCallback(callback)
    @connection.knex().schema.createTable(@table_name, (t) => callback(null, t)).exec(callback)
    return @

  editTable: (callback) =>
    throw new Error "editTable requires a callback" unless _.isFunction(callback)

    callback = debounceCallback(callback)
    @connection.knex().schema.table(@table_name, (t) => callback(null, t)).exec(callback)
    return @

  addField: (table, key, field) =>
    type = "#{field.type[0].toLowerCase()}#{field.type.slice(1)}"
    @addColumn(table, key, type, field)
    return @

  addIDColumn: (table) => @addColumn(table, 'id', 'increments', ['primary'])

  addColumn: (table, key, type, options={}) =>
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

    column = table[type].apply(table, column_args)

    knex_methods = []
    knex_methods.push['notNullable'] if options.nullable is false
    knex_methods.push('index') if options.indexed
    knex_methods.push('unique') if options.unique

    column[method]() for method in knex_methods

    return @

  addRelation: (table, key, relation) =>
    return if relation.isVirtual() # skip virtual
    if relation.type is 'belongsTo'
      @addColumn(table, relation.foreign_key, 'integer', ['nullable', 'index'])
    else if relation.type is 'hasMany' and relation.reverse_relation.type is 'hasMany'
      @join_table_operations.push((callback) -> relation.findOrGenerateJoinTable().db().ensureSchema(callback))
    return @

  resetRelation: (table, key, relation) =>
    return if relation.isVirtual() # skip virtual
    if relation.type is 'belongsTo'
      @addColumn(table, relation.foreign_key, 'integer', ['nullable', 'index'])
    else if relation.type is 'hasMany' and relation.reverse_relation.type is 'hasMany'
      @join_table_operations.push((callback) -> relation.findOrGenerateJoinTable().resetSchema(callback))
    return @

  resetSchema: (options, callback) =>
    (callback = options; options = {}) if arguments.length is 1

    @connection.knex().schema.dropTableIfExists(@table_name).exec (err) =>
      return callback(err) if err

      @createTable (err, table) =>
        return callback(err) if err
        console.log "Creating table: #{@table_name} with fields: '#{_.keys(@schema.fields).join(', ')}' and relations: '#{_.keys(@schema.relations).join(', ')}'" if options.verbose

        @addIDColumn(table)
        @addField(table, key, field) for key, field of @schema.fields
        @resetRelation(table, key, relation) for key, relation of @schema.relations

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
        @createTable (err, table) =>
          return callback(err) if err
          @addIDColumn(table)
          @end (err) =>
            (@ensuring = false; return callback(err)) if err
            return @ensureSchemaForExistingTable(options, (err) => @ensuring = false; callback(err))
      else
        return @ensureSchemaForExistingTable(options, (err) => @ensuring = false; callback(err))

  # Should only be called once the table exists - can't do column checks unless the table has been created
  # Should only be called by @ensureSchema, sets @ensuring to false when complete
  ensureSchemaForExistingTable: (options, callback) =>
    @editTable (err, table) =>
      return callback(err) if err

      queue = new Queue(1)
      queue.defer (callback) => @ensureColumn(table, 'id', 'increments', ['primary'], callback)

      if @schema.fields
        for key, field of @schema.fields
          do (key, field) => queue.defer (callback) =>
            @ensureField(table, key, field, callback)

      if @schema.relations
        for key, relation of @schema.relations
          do (key, relation) => queue.defer (callback) =>
            @ensureRelation(table, key, relation, callback)

      queue.await (err) =>
        return callback(err) if err
        @end(callback)

  ensureRelation: (table, key, relation, callback) =>
    if relation.type is 'belongsTo'
      @hasColumn relation.foreign_key, (err, column_exists) =>
        return callback(err) if err
        @addRelation(table, key, relation) unless column_exists
        callback()
    else if relation.type is 'hasMany' and relation.reverse_relation.type is 'hasMany'
      relation.findOrGenerateJoinTable().db().ensureSchema(callback)
    else
      callback()

  ensureField: (table, key, field, callback) =>
    @hasColumn key, (err, column_exists) =>
      return callback(err) if err
      @addField(table, key, field) unless column_exists
      callback()

  ensureColumn: (table, key, type, options, callback) =>
    @hasColumn key, (err, column_exists) =>
      return callback(err) if err
      @addColumn(table, key, type, options) unless column_exists
      callback()

  # knex method wrappers
  hasColumn: (column, callback) => @connection.knex().schema.hasColumn(@table_name, column).exec callback
  hasTable: (callback) => @connection.knex().schema.hasTable(@table_name).exec callback
  dropTable: (callback) => @connection.knex().schema.dropTable(@table_name).exec callback
  dropTableIfExists: (callback) => @connection.knex().schema.dropTableIfExists(@table_name).exec callback
  renameTable: (to, callback) => @connection.knex().schema.renameTable(@table_name, to).exec callback
