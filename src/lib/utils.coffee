{DatabaseURL} = require 'backbone-orm'

PROTOCOLS =
  'mysql:': 'mysql', 'mysql2:': 'mysql'
  'postgres:': 'postgres', 'pg:': 'postgres'
  'sqlite:': 'sqlite3', 'sqlite3:': 'sqlite3'

module.exports = class Utils
  @protocolType: (url) ->
    url = new DatabaseURL(url) unless url.protocol
    PROTOCOLS[url.protocol]
