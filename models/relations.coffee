Sequelize = require 'sequelize'
sequelize = require '../db/sequelize'
BackboneSequelize = require '../db/backbone_sequelize'

Photo = require('../models/photo').schema
Album = require('../models/album').schema

#Photo
#  .hasOne(Album,  { foreignKey: 'album_id' })

Album
  .hasMany(Photo, { foreignKey: 'album_id' })