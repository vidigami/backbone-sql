util = require 'util'
URL = require 'url'
_ = require 'underscore'
Knex = require 'knex'
connections = {}

module.exports =
  get: (parameters) ->
    return connections[parameters.database_path] if connections[parameters.database_path]

    connection = _.extend(_.pick(parameters, ['host', 'user', 'password', 'database']), {charset: 'utf8'})
    url_parts = URL.parse(parameters.database_path)
    switch url_parts.protocol
      when 'mysql:'
        return connections[parameters.database_path] = Knex.Initialize(parameters.database_path, {client: 'mysql', connection: connection})
      when 'postgres:'
        return connections[parameters.database_path] = Knex.Initialize(parameters.database_path, {client: 'postgres', connection: connection})
      when 'sqlite3:'
        return connections[parameters.database_path] = Knex.Initialize(parameters.database_path, {client: 'sqlite3', connection: connection})
      else
        throw "Unrecognized sql variant: #{parameters.database_path} for protocol: #{url_parts.protocol}"
