_ = require 'underscore'
Queue = require 'backbone-orm/lib/queue'

# DATABASE_VARIANTS = ['mysql']
DATABASE_VARIANTS = ['postgres']
# DATABASE_VARIANTS = ['sqlite3']
# DATABASE_VARIANTS = ['mysql', 'postgres']
# DATABASE_VARIANTS = ['mysql', 'postgres', 'sqlite3']

module.exports = (options, callback) ->
  test_parameters =
    schema:
      created_at: 'DateTime'
      updated_at: 'DateTime'
      name: ['String', indexed: true]
      # TODO: json only works on the postgres backend
      json_data: 'json'  # for flat/cursor
      is_base: 'Boolean'  # for relational/self
    sync: require('../../lib/sync')

  queue = new Queue(1)
  for variant in DATABASE_VARIANTS
    do (variant) -> queue.defer (callback) ->
      console.log "\n-------------------------------------"
      console.log "Running tests for variant: #{variant}"
      console.log "-------------------------------------"
      variant_test_parameters = _.extend({}, test_parameters, options)
      variant_test_parameters.database_url = require('../config/database')[variant]
      require('backbone-orm/test/generators/all')(variant_test_parameters, callback)
  queue.await callback
