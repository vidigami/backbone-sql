_ = require 'underscore'
Knex = require 'knex'

ConnectionPool = require 'backbone-orm/lib/connection_pool'
DatabaseUrl = require 'backbone-orm/lib/database_url'

PROTOCOLS =
  'mysql:': 'mysql', 'mysql2:': 'mysql'
  'postgres:': 'postgres', 'pg:': 'postgres'
  'sqlite:': 'sqlite3', 'sqlite3:': 'sqlite3'

class KnexConnection
  constructor: (@knex) ->
  destroy: -> # TODO: look for a way to close knex

module.exports = class Connection
  constructor: (full_url) ->
    database_url = new DatabaseUrl(full_url)
    @url = database_url.format({exclude_table: true, exclude_query: true}) # pool the raw endpoint without the table
    return if @knex_connection = ConnectionPool.get(@url) # found in pool

    throw "Unrecognized sql variant: #{full_url} for protocol: #{database_url.protocol}" unless protocol = PROTOCOLS[database_url.protocol]
    connection_info = _.extend({host: database_url.hostname, database: database_url.database, charset: 'utf8'}, database_url.parseAuth() or {})
    knex = Knex.initialize({client: protocol, connection: connection_info})
    ConnectionPool.set(@url, @knex_connection = new KnexConnection(knex))

  knex: -> return @knex_connection?.knex
