global.__test__parameters = module.exports =
  schema:
    created_at: 'DateTime'
    updated_at: 'DateTime'
    name: ['String', indexed: true]
    # TODO: json only works on the postgres backend
    # json_data: 'JSON'  # for flat/cursor
    is_base: 'Boolean'  # for relational/self
    # test: ['String', length: 500]
  database_url: require('./config/database')['sqlite3']
  sync: require('../').sync
  $parameter_tags: '@sqlite3_sync '
