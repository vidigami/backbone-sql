util = require 'util'
URL = require 'url'
_ = require 'underscore'
Queue = require 'queue-async'
mysql = require 'mysql'

module.exports = class Connection

  constructor: (@url, @schema={}) ->
    @collection_requests = []
    throw new Error 'Expecting a string url' unless _.isString(@url)
    url_parts = URL.parse(@url)
    config =
      host: url_parts.hostname
      port: url_parts.port
    if url_parts.auth
      auth_parts = url_parts.auth.split(':')
      config.user = auth_parts[0]
      config.password = if auth_parts.length > 1 then auth_parts[1] else null

    database_parts = url_parts.pathname.split('/')
    database = database_parts[1]
    table = database_parts[2]

    console.log "MySQL for '#{database}' is: '#{config.host}:#{config.port}'"
    @connection = mysql.createConnection(config)

    @connection.connect (err) =>
      if err
        console.error 'Could not connect to mysql db: ', config

  ##
  # Close the database connection
  ##
  close: ->
    @connection.end()
