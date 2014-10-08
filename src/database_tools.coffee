###
  backbone-sql.js 0.6.5
  Copyright (c) 2013 Vidigami - https://github.com/vidigami/backbone-sql
  License: MIT (http://www.opensource.org/licenses/mit-license.php)
###

Knex = require 'knex'
{_, Queue} = require 'backbone-orm'

KNEX_COLUMN_OPTIONS = ['textType', 'length', 'precision', 'scale', 'value', 'values']

# TODO: when knex fixes join operator, remove this deprecation warning
knex_helpers = require 'knex/lib/helpers'
KNEX_SKIP = ['The five argument join']
_deprecate = knex_helpers.deprecate
knex_helpers.deprecate = (msg) -> _deprecate.apply(@, _.toArray(arguments)) if msg.indexOf(KNEX_SKIP) isnt 0

KNEX_TYPES =
  datetime: 'dateTime'
  biginteger: 'bigInteger'

module.exports = class DatabaseTools

  constructor: (@connection, @table_name, @schema, options={}) ->

  resetSchema: (options, callback) =>
    [callback, options] = [options, {}] if arguments.length is 1
    return callback() if @resetting
    @resetting = true

    queue = new Queue(1)
    queue.defer (callback) => @connection.knex().schema.dropTableIfExists(@table_name).exec callback
    queue.defer (callback) =>
      join_queue = new Queue(1)
      for join_table in @schema.joinTables()
        do (join_table) => join_queue.defer (callback) => join_table.db().resetSchema(callback)
      join_queue.await callback
    queue.await (err) =>
      @resetting = false; return callback(err) if err
      @ensureSchema(options, callback)

  # Ensure that the schema is reflected correctly in the database
  # Will create a table and add columns as required will not remove columns (TODO)
  ensureSchema: (options, callback) =>
    [callback, options] = [options, {}] if arguments.length is 1

    return callback() if @ensuring
    @ensuring = true

    queue = new Queue(1)
    queue.defer (callback) => @createOrUpdateTable(options, callback)
    queue.defer (callback) =>
      join_queue = new Queue(1)
      for join_table in @schema.joinTables()
        do (join_table) => join_queue.defer (callback) => join_table.db().ensureSchema(callback)
      join_queue.await callback

    queue.await (err) => @ensuring = false; callback(err)

  createOrUpdateTable: (options, callback) =>
    @hasTable (err, table_exists) =>
      return callback(err) if err
      console.log "Ensuring table: #{@table_name} (exists: #{!!table_exists}) with fields: '#{_.keys(@schema.fields).join(', ')}' and relations: '#{_.keys(@schema.relations).join(', ')}'" if options.verbose

      columns = []

      # look up the add or update columns
      # NOTE: Knex requires the add an update operations to be performed within the table function.
      # This means that hasColumn being asynchronous requires the check to be done before calling the table function
      for key in @schema.columns()
        if field = @schema.fields[key]
          type = override if override = KNEX_TYPES[type = field.type.toLowerCase()]
          columns.push({key: key, type: type, options: field})
        else if key is 'id'
          columns.push({key: key, type: 'increments', options: {indexed: true, primary: true}})

      for key, relation of @schema.relations when (relation.type is 'belongsTo') and not relation.isVirtual() and not relation.isEmbedded()
        do (key, relation) => columns.push({key: relation.foreign_key, type: 'integer', options: {indexed: true, nullable: true}})

      group = (columns, callback) =>
        return callback(null, {add: columns, update: []}) unless table_exists

        result = {add: [], update: []}

        queue = new Queue()
        for column_info in columns
          do (column_info) => queue.defer (callback) =>
            @hasColumn column_info.key, (err, exists) =>
              return callback(err) if err
              (if exists then result.update else result.add).push(column_info); return callback()
        queue.await (err) => callback(err, result)

      group columns, (err, result) =>
        return callback(err) if err
        @connection.knex().schema[if table_exists then 'table' else 'createTable'](@table_name, (table) =>
          @addColumn(table, column_info) for column_info in result.add
          @updateColumn(table, column_info) for column_info in result.update
        ).exec(callback)
    return

  addColumn: (table, column_info) =>
    column_args = [column_info.key]

    # Assign column specific arguments
    constructor_options = _.pick(column_info.options, KNEX_COLUMN_OPTIONS)
    unless _.isEmpty(constructor_options)
      # Special case as they take two args
      if column_info.type in ['float', 'decimal']
        column_args[1] = constructor_options['precision']
        column_args[2] = constructor_options['scale']
      # Assume we've been given one valid argument
      else
        column_args[1] = _.values(constructor_options)[0]

    column = table[column_info.type].apply(table, column_args)
    column.nullable() if !!column_info.options.nullable
    column.primary() if !!column_info.options.primary
    column.index() if !!column_info.options.indexed
    column.unique() if !!column_info.options.unique

    return

  # TODO: handle column type changes and figure out how to update columns properly
  updateColumn: (table, column_info) =>
    # table.index(column_info.key) if column_info.options.indexed # fails if the column already exists
    # table.unique(column_info.key) if column_info.options.unique
    return

  # knex method wrappers
  hasColumn: (column, callback) => @connection.knex().schema.hasColumn(@table_name, column).exec callback
  hasTable: (callback) => @connection.knex().schema.hasTable(@table_name).exec callback
  dropTable: (callback) => @connection.knex().schema.dropTable(@table_name).exec callback
  dropTableIfExists: (callback) => @connection.knex().schema.dropTableIfExists(@table_name).exec callback
  renameTable: (to, callback) => @connection.knex().schema.renameTable(@table_name, to).exec callback
