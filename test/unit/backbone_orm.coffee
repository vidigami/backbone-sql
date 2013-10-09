_ = require 'underscore'
Queue = require 'queue-async'

#DATABASE_VARIANTS = ['mysql']
DATABASE_VARIANTS = ['postgres']
#DATABASE_VARIANTS = ['mysql', 'postgres']
#DATABASE_VARIANTS = ['mysql', 'postgres', 'sqlite3']

module.exports = (options, callback) ->
  test_parameters =
    schema:
      created_at: 'DateTime'
      updated_at: 'DateTime'
      name: ['String', indexed: true]
    sync: require('../../sync')

  queue = new Queue(1)
  for variant in DATABASE_VARIANTS
    do (variant) -> queue.defer (callback) ->
      console.log "Running tests for variant: #{variant}"
      variant_test_parameters = _.extend({}, test_parameters, options)
      variant_test_parameters.database_url = require('../config/database')[variant]
      require('backbone-orm/test/generators/all')(variant_test_parameters, callback)
  queue.await callback
