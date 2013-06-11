_ = require 'underscore'
Backbone = require 'backbone'

class Album extends Backbone.Model
  updateCoverPhoto: ->
    @set({cover_photo: (if @get('photos').length then @get('photos').models[0] else null)})
    return @

  updateFeaturedPhotos: ->
    sorted_photos = _.sortBy(@get('photos').models, (test) -> -test.get('created_at').valueOf())
    @set({featured_photos: sorted_photos.splice(0, 8)}) # maximum number featured photos
    return @

module.exports = class ServerAlbum extends Album
  @schema:
    created_at: 'Date'
    updated_at: 'Date'

    name: ['String', indexed: true]
    description: 'String'
    label: 'String'
    zipspawn_id: 'Integer'
    zipspawn_name: 'String'
    start: 'Date'
    stop: 'Date'
    active: 'Boolean'
    editable: 'Boolean'
    last_changed: 'Date'

    photos: -> ['hasMany', require('./photo')]

  url: "#{require('../config/database')['test']}/albums"
  sync: require('../../backbone_sync')(ServerAlbum)
