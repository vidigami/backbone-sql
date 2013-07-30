Sequelize = require 'sequelize'

module.exports =
  String: 'string'
  Date: 'date'
  DateTime: 'dateTime'
  Boolean: 'boolean'
  Integer: Sequelize.INTEGER
  Float: Sequelize.FLOAT
