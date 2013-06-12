_ = require 'underscore'
Sequelize = require 'sequelize'
SchemaParser = require 'backbone-node/lib/parsers/schema'

module.exports = class SequelizeSchemaParser extends SchemaParser

  @db_types:
    'String': Sequelize.STRING
    'Date': Sequelize.DATE
    'Boolean': Sequelize.BOOLEAN
    'Integer': Sequelize.INTEGER
    'Float': Sequelize.FLOAT
