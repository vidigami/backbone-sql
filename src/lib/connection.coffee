###
  backbone-sql.js 0.6.5
  Copyright (c) 2013 Vidigami - https://github.com/vidigami/backbone-sql
  License: MIT (http://www.opensource.org/licenses/mit-license.php)
###

Knex = require 'knex'
{_, Queue, DatabaseURL, ConnectionPool} = require 'backbone-orm'

Utils = require './utils'

class KnexConnection
  constructor: (@knex) ->
  destroy: -> # TODO: look for a way to close knex

module.exports = class Connection
  constructor: (full_url) ->
    database_url = new DatabaseURL(full_url)
    @url = database_url.format({exclude_table: true, exclude_query: true}) # pool the raw endpoint without the table
    return if (@knex_connection = ConnectionPool.get(@url)) # found in pool

    throw "Unrecognized sql variant: #{full_url} for protocol: #{database_url.protocol}" unless protocol = Utils.protocolType(database_url)

    if protocol is 'sqlite3'
      connection_info = {filename: database_url.host or ':memory:'}
    else
      connection_info = _.extend({host: database_url.hostname, database: database_url.database, charset: 'utf8'}, database_url.parseAuth() or {})

    knex = Knex.initialize({client: protocol, connection: connection_info})
    ConnectionPool.set(@url, @knex_connection = new KnexConnection(knex))

  knex: -> return @knex_connection?.knex
