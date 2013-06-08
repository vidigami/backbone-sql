moment = require 'moment'
Backbone = require 'backbone'

class Photo extends Backbone.Model
  defaults: ->
    return {
      created_at: moment.utc().toDate()
    }

module.exports = class ServerPhoto extends Photo
  @schema:
    created_at: 'Date'
    updated_at: 'Date'

    source_file_name: 'String'
    source_file_size: 'Integer'
    source_content_type: 'String'
    title: 'String'
    description: 'String'
    taken_at: 'Date'
    rotation: 'Integer'
    public_link_name: 'String'
    height: 'Integer'
    width: 'Integer'
    aspect_ratio: 'Float'
    pid: 'String'
    process_finished: 'Boolean'
    original_public_link_name: 'String'
    # is_flagged: 'Boolean' # removed
    # is_corrupted: 'Boolean'

    album: -> ['hasOne', require('./album'), indexed: true]

  url: require('../config/databases/photos')['test']
  sync: require('../../backbone_sync')(ServerPhoto)
