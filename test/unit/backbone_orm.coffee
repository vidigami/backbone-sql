module.exports = (options, callback) ->
  test_parameters =
    database_url: require('../config/database')['test']
    schema:
      created_at: 'DateTime'
      updated_at: 'DateTime'
      name: ['String', indexed: true]
    sync: require('../../sync')

  require('backbone-orm/test/generators/all')(test_parameters, callback)
