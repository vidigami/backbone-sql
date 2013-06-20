test_parameters =
  database_url: require('../config/database')['test']
  schema:
    created_at: 'Date'
    updated_at: 'Date'
    name: ['String', indexed: true]
  sync: require('../../backbone_sync')

require('backbone-orm/test/generators/all')(test_parameters)
