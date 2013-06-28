Sequelize = require 'sequelize'
connections = {}

module.exports =
  get: (url) ->
    return connections[url] if connections[url]
    return connections[url] = new Sequelize(url, {dialect: 'mysql', logging: false})
