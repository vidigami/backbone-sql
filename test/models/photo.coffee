moment = require 'moment'
Backbone = require 'backbone'

module.exports = class Photo extends Backbone.Model
  @schema:
    created_at: 'Date'
    updated_at: 'Date'

    source_file_name: 'String'

    album: -> ['belongsTo', require('./album')]

  url: "#{require('../config/database')['test']}/photos"
  sync: require('../../backbone_sync')(Photo)
