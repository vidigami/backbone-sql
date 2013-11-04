_ = require 'underscore'
Queue = require 'backbone-orm/lib/queue'

#DATABASE_VARIANTS = ['mysql']
#DATABASE_VARIANTS = ['postgres']
#DATABASE_VARIANTS = ['sqlite3']
#DATABASE_VARIANTS = ['mysql', 'postgres']
DATABASE_VARIANTS = ['mysql', 'postgres', 'sqlite3']

module.exports = (options, callback) ->
  test_parameters =
    schema:
      created_at: 'DateTime'
      updated_at: 'DateTime'
      name: ['String', indexed: true]
      test: ['String', length: 500]
    sync: require('../../src/sync')

  queue = new Queue(1)
  for variant in DATABASE_VARIANTS
    do (variant) -> queue.defer (callback) ->
      console.log "\n-------------------------------------"
      console.log "Running tests for variant: #{variant}"
      console.log "-------------------------------------"
      variant_test_parameters = _.clone(test_parameters)
      variant_test_parameters.database_url = require('../config/database')[variant]
      require('../generators/database_tools')(variant_test_parameters, callback)
      require('../generators/master_slave')(variant_test_parameters, callback)
  queue.await callback
