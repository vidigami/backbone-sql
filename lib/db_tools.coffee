
When = require 'when'
WhenNodeFn = require 'when/node/function'


module.exports = class DatabaseTools

  constructor: (@connection, @table, @schema) ->

  addColumn: (table, field, callback) =>
    @connection.table(table, (table) =>

    ).then(callback)


  resetSchema: (options, callback) =>
    join_tables = []

    @connection.Schema.dropTableIfExists(@table).exec (err) =>
      return callback(err) if err

      @connection.Schema.createTable(@table, (table) =>
        console.log "Creating table: #{@table} with fields: \'#{_.keys(@schema.fields).join(', ')}\' and relations: \'#{_.keys(@schema.relations).join(', ')}\'" if options.verbose

        table.increments('id').primary()
        for key, field of @schema.fields
          method = "#{field.type[0].toLowerCase()}#{field.type.slice(1)}"
          col = table[method](key).nullable()
          col.index() if field.indexed
          col.unique() if field.unique

        for key, relation of @schema.relations
          continue if relation.isVirtual() # skip virtual
          if relation.type is 'belongsTo'
            table.integer(relation.foreign_key).nullable().index()
          else if relation.type is 'hasMany' and relation.reverse_relation.type is 'hasMany'
            do (relation) ->
              join_tables.push(WhenNodeFn.call((callback) -> relation.findOrGenerateJoinTable().resetSchema(callback)))
        return
      )
      .then(-> When.all(join_tables))
      .then((-> callback()), callback)
