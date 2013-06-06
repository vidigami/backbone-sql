Backbone = require 'backbone'
Photo = require './photo'

module.exports = class Photos extends Backbone.Collection
  model: Photo