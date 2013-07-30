Knex = require 'knex'
connections = {}

module.exports =
  get: (parameters) ->
    return connections[parameters.database_path] if connections[parameters.database_path]
    return connections[parameters.database_path] = ( ->
      Knex.Initialize(
        client: 'mysql'
        connection: {
          host     : parameters.host
          user     : parameters.user
          password : parameters.password
          database : parameters.database
          charset  : 'utf8'
        }
      )
    )()