Queue = require 'queue-async'

queue = new Queue(1)
queue.defer (callback) -> require('./unit/backbone_orm')({}, callback)
#queue.defer (callback) -> require('./unit/backbone_rest')({}, callback)
queue.await (err) -> console.log "Backbone SQL: Completed tests"
