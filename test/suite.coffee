Queue = require 'backbone-orm/lib/queue'

ModelTypeID = require('backbone-orm/lib/cache/singletons').ModelTypeID
ModelTypeID.strict = false

option_sets = require('backbone-orm/test/option_sets')
# option_sets = option_sets.slice(0, 1)

test_queue = new Queue(1)
for options in option_sets
  do (options) -> test_queue.defer (callback) ->
    return callback() if options.embed
    console.log "\nBackbone SQL: Running tests with options:\n", options
    queue = new Queue(1)
    queue.defer (callback) -> require('./unit/backbone_orm')(options, callback)
    queue.defer (callback) -> require('./unit/backbone_rest')(options, callback)
    # queue.defer (callback) -> require('./unit/database')(options, callback)
    queue.await callback
test_queue.await (err) -> console.log "Backbone SQL: Completed tests"
