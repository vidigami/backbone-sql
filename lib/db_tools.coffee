Knex = require 'knex'
When = require 'when'
WhenNodeFn = require 'when/node/function'


module.exports = class DatabaseTools

  constructor: (@connection, @table_name, @schema) ->

  end: (callback) =>
    return callback(new Error('end() called with no operations in progress, call createTable or editTable first')) unless @promise
    @promise.exec(callback)

  createTable: =>
    throw Error("Table operation already in progress, call end() first") if @promise or @table
    @promise = @connection.Schema.createTable(@table_name, (t) => @table = t)
    return @table

  editTable: =>
    throw Error("Table operation already in progress, call end() first") if @promise or @table
    @promise = @connection.Schema.table(@table_name, (t) => @table = t)
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

  resetSchema: (options, callback) =>
    join_tables = []

    @connection.Schema.dropTableIfExists(@table_name).exec (err) =>
      return callback(err) if err

#      @createTable (err, table) =>
#        return callback(err) if err
#        console.log 2

#      console.log '-----'
#      console.log @createTable()
#      console.log '-----'

      @table = @createTable()
#      console.log @promise
#      @connection.Schema.createTable(@table_name, (table) =>
      console.log "Creating table: #{@table_name} with fields: '#{_.keys(@schema.fields).join(', ')}' and relations: '#{_.keys(@schema.relations).join(', ')}'" if options.verbose

      @addColumn('id', 'increments', ['primary'])
      @addField(key, field) for key, field of @schema.fields
#        method = "#{field.type[0].toLowerCase()}#{field.type.slice(1)}"
#        col = table[method](key).nullable()
#        col.index() if field.indexed
#        col.unique() if field.unique

      for key, relation of @schema.relations
        continue if relation.isVirtual() # skip virtual
        if relation.type is 'belongsTo'
          table.integer(relation.foreign_key).nullable().index()
        else if relation.type is 'hasMany' and relation.reverse_relation.type is 'hasMany'
          do (relation) ->
            join_tables.push(WhenNodeFn.call((callback) -> relation.findOrGenerateJoinTable().resetSchema(callback)))

#        console.log 3
#        @end (err) =>
#          return callback(err) if err
#          When.all(join_tables)
#          callback()
#      )
      @promise.then(-> When.all(join_tables))
      @promise.then((-> callback()), callback)
