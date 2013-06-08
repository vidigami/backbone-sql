NODE_ENV = process.env.NODE_ENV || 'development'
config_app = require('./config/app')[NODE_ENV]

moment = require 'moment'

class Config

  @env: -> NODE_ENV
  @VERBOSE = !!config_app.verbose

  @port: -> config_app.port
  @origins: -> config_app.allow_origins

  @pageExpiration: -> moment.utc().add('minutes', 12*60).toDate()

module.exports = Config