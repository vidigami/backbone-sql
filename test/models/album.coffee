_ = require 'underscore'
Backbone = require 'backbone'

module.exports = class Album extends Backbone.Model
  @schema:
    created_at: 'Date'
    updated_at: 'Date'

    name: ['String', indexed: true]

    photos: -> ['hasMany', require('./photo')]
#    photo: -> ['hasOne', require('./photo'), reverse: true]

  url: "#{require('../config/database')['test']}/albums"
  sync: require('../../backbone_sync')(Album)
