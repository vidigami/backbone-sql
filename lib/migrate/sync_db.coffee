_ = require 'underscore'
Queue = require 'queue-async'
Knex = require 'knex'
inflection = require 'inflection'

module.exports = class SyncDB

  @drop: (model_types, options, callback) ->
    options = {} if arguments.length is 1
    (callback = options; options={}) if arguments.length is 2

    queue = new Queue()
    count = 0
    for name, model_type of model_types
      do (name, model_type) ->
        queue.defer (callback) ->
          new model_type().sync('initialize')
          model_type._connection.Schema.dropTableIfExists(model_type._table)
              .then(( ->
                console.log('dropped table', model_type._table) if options.verbose
                count++
                callback()
              ), ((err) -> console.error err; callback(err))
            )

    queue.await ->
      console.log "#{count} tables dropped" if options.verbose
      callback() if callback

  @create: (model_types, options, callback) ->
    options = {} if arguments.length is 1
    (callback = options; options={}) if arguments.length is 2

    console.log("creating #{_.keys(model_types).length} tables") if options.verbose

    queue = new Queue()
    count = 0
    for name, model_type of model_types
      do (name, model_type) ->
        queue.defer (callback) ->
          model_type._connection.Schema.createTable(model_type._table, (table) ->
            table.increments('id').primary()
            for key, field of model_type._fields
              method = "#{field.type[0].toLowerCase()}#{field.type.slice(1)}"
              table[method](key).nullable()

            for key, relation of model_type._relations
              if relation.type is 'belongsTo'
                table.integer(relation.foreign_key).nullable()
              else if relation.type is 'hasMany' and relation.reverse_relation.type is 'hasMany'
                #todo: many to many join table creation
                console.log 'todo: manytomany'
          ).then(
            ( ->
              console.log('created table', model_type._table) if options.verbose
              count++
              callback()
            ), ((err) -> console.error err; callback(err))
          )

    queue.await ->
      console.log "#{count} tables synced" if options.verbose
      callback() if callback

  @sync: (model_types, options, callback) ->
    SyncDB.drop model_types, options, (err) ->
      return callback(err) if err
      SyncDB.create model_types, options, callback
