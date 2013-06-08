Backbone = require 'backbone'
User = require './user'

module.exports = class Users extends Backbone.Collection
  model: User