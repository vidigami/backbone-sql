Backbone = require 'backbone'
ServerAlbum = require './album'

module.exports = class Albums extends Backbone.Collection
  model: ServerAlbum