_ = require 'underscore'
Knex = require 'knex'
connections = {}

module.exports =
  get: (parameters) ->
    return connections[parameters.database_path] if connections[parameters.database_path]
    return connections[parameters.database_path] = Knex.Initialize(parameters.database_path,
      client: 'mysql'
      connection: _.extend(_.pick(parameters, ['host', 'user', 'password', 'database']), {charset: 'utf8'})
    )
