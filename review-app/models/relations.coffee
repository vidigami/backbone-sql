Sequelize = require 'sequelize'
sequelize = require '../lib/sequelize'
BackboneSequelize = require '../lib/backbone_sequelize'

Photo = require('../models/photo').schema
Album = require('../models/album').schema

#Photo
#  .hasOne(Album,  { foreignKey: 'album_id' })

Album
  .hasMany(Photo, { foreignKey: 'album_id' })