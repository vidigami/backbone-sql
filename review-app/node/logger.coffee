bunyan = require 'bunyan'

module.exports = bunyan.createLogger(
  name: 'review'
  stream: process.stdout
  level: 'info'
)