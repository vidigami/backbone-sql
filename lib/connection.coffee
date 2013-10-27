_ = require 'underscore'
Knex = require 'knex'

ConnectionPool = require 'backbone-orm/lib/connection_pool'
DatabaseUrl = require 'backbone-orm/lib/database_url'

class KnexConnection
  constructor: (@knex) ->
  destroy: -> # TODO: look for a way to close knex

PROTOCOLS =
  'mysql:': 'mysql', 'mysql2:': 'mysql'
  'postgres:': 'postgres', 'pg:': 'postgres'
  'sqlite:': 'sqlite3', 'sqlite3:': 'sqlite3'

module.exports = class Connection
  constructor: (@url) ->
    return if @knex_connection = ConnectionPool.get(@url) # found in pool

    url = new DatabaseUrl(@url)
    throw "Unrecognized sql variant: #{@url} for protocol: #{url.protocol}" unless protocol = PROTOCOLS[url.protocol]
    knex = Knex.initialize({client: protocol, connection: _.extend(_.pick(url, ['host', 'database']), {charset: 'utf8'}, url.parseAuth() or {})})
    ConnectionPool.set(@url, @knex_connection = new KnexConnection(knex))

  knex: -> return @knex_connection?.knex
