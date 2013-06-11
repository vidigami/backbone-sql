logger = require 'vidigami/node/logger'
ServerAlbum = require '../../models/album'
RestController = require 'backbone-rest'

module.exports = class AlbumsController extends RestController

  route: 'albums'
  model_type: ServerAlbum
