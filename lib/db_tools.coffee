_ = require 'underscore'
Knex = require 'knex'
Queue = require 'queue-async'

module.exports = class DatabaseTools

  constructor: (@connection, @table_name, @schema) ->
    @join_table_operations = []
    @reset()

  reset: => @promise = @table = null

  end: (callback) =>
    return callback(new Error('end() called with no operations in progress, call createTable or editTable first')) unless @promise
#    @promise.then(-> ) if @join_table_operations.length
    @promise.exec (err) =>
      # Always reset state
      @reset()
      console.log 'END', @table_name
      return callback(err) if err
      console.log @join_table_operations.length
      if @join_table_operations.length
        queue = new Queue(1)
        for join_table_fn in @join_table_operations
          do (join_table_fn) => queue.defer (callback) =>
            join_table_fn(callback)
        queue.await (err) => @join_table_operations = []; callback(err)
      else
        callback()

  createTable: =>
    throw Error("Table operation on #{@table_name} already in progress, call end() first") if @promise or @table
    @promise = @connection.schema.createTable(@table_name, (t) => @table = t)
    return @table

  editTable: =>
    throw Error("Table operation on #{@table_name} already in progress, call end() first") if @promise or @table
    @promise = @connection.schema.table(@table_name, (t) => @table = t)
    return @table

  addField: (key, field) =>
    @table = @editTable() unless @table
    type = "#{field.type[0].toLowerCase()}#{field.type.slice(1)}"
    options = ['nullable']
    options.push('index') if field.indexed
    options.push('unique') if field.unique
    @addColumn(key, type, options)

  addColumn: (key, type, options) =>
    @table = @editTable() unless @table
    column = @table[type](key)
    column[method]() for method in options

  resetRelation: (key, relation) =>
    @table = @editTable() unless @table
    return if relation.isVirtual() # skip virtual
    if relation.type is 'belongsTo'
      @addColumn(relation.foreign_key, 'integer', ['nullable', 'index'])
    else if relation.type is 'hasMany' and relation.reverse_relation.type is 'hasMany'
      @join_table_operations.push((callback) -> relation.findOrGenerateJoinTable().resetSchema(callback))
#      @join_table_operations.push(WhenNodeFn.call((callback) -> relation.findOrGenerateJoinTable().resetSchema(callback)))

  addRelation: (key, relation) =>
    @table = @editTable() unless @table
    return if relation.isVirtual() # skip virtual
    if relation.type is 'belongsTo'
      @addColumn(relation.foreign_key, 'integer', ['nullable', 'index'])
    else if relation.type is 'hasMany' and relation.reverse_relation.type is 'hasMany'
      @join_table_operations.push((callback) -> relation.findOrGenerateJoinTable().resetSchema(callback))
#      @join_table_operations.push(WhenNodeFn.call((callback) -> relation.findOrGenerateJoinTable().resetSchema(callback)))

  resetSchema: (options, callback) =>

    console.log 'RESETTING', @table_name
    @connection.schema.dropTableIfExists(@table_name).exec (err) =>
      return callback(err) if err

      @table = @createTable()
      console.log "Creating table: #{@table_name} with fields: '#{_.keys(@schema.fields).join(', ')}' and relations: '#{_.keys(@schema.relations).join(', ')}'" if options.verbose

      @addColumn('id', 'increments', ['primary'])
      @addField(key, field) for key, field of @schema.fields
      @resetRelation(key, relation) for key, relation of @schema.relations

      @end(callback)
