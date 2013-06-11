moment = require 'moment'
Backbone = require 'backbone'

Sequelize = require 'sequelize'

class Photo extends Backbone.Model

  defaults: ->
    return {
      created_at: moment.utc().toDate()
    }


module.exports = class ServerPhoto extends Photo

  @schema:
    source_file_name: 'String'

    created_at: 'Date'
    updated_at: 'Date'

    source_content_type: 'String'
    source_file_size: 'Integer'
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
    is_flagged: 'Boolean'
    is_corrupted: 'Boolean'
    image_id: 'String'

    album: -> ['hasOne', require('./album'), indexed: true]

  url: "#{require('../config/database')['dev']}/photos"
  sync: require('../../backbone_sync')(ServerPhoto)
