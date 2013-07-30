_ = require 'underscore'
Queue = require 'queue-async'
Knex = require 'knex'
inflection = require 'inflection'

module.exports = class SyncDb

  @drop: (model_types, options, callback) ->
    options = {} if arguments.length is 1
    (callback = options; options={}) if arguments.length is 2

    queue = new Queue()

    count = 0
    for name, model_type of model_types
      do (name, model_type) ->
        queue.defer (callback) ->
          Knex.Schema.dropTableIfExists(model_type._table).then(( ->
              console.log('dropped table', model_type._table) if options.verbose
              callback()
            ), ((err) -> console.error err; callback())
          )

    queue.await ->
      console.log "#{count} tables dropped" if options.verbose
      callback() if callback

  @create: (model_types, options, callback) ->
    options = {} if arguments.length is 1
    (callback = options; options={}) if arguments.length is 2

    console.log("syncing #{_.keys(model_types).length} tables") if options.verbose

    # sync all
    queue = new Queue()

    count = 0
    for name, model_type of model_types
      do (name, model_type) ->
        queue.defer (callback) ->
          Knex.Schema.table(model_type._table, (table) ->
            for field, type of model_type._fields
              console.log name, value
              table[camelize(type, true)](field)
          ).then(( ->
              console.log('created table', model_type._table) if options.verbose
              count++
              callback()
            ), ((err) -> console.error err; callback())
          )

    queue.await ->
      console.log "#{count} tables synced" if options.verbose
      callback() if callback

  @sync: (model_types, options, callback) ->
    SyncDb.drop model_types, options, (err) ->
      return callback(err) if err
      SyncDb.create model_types, options, callback
