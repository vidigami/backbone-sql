logger = require '../../node/logger'
ServerPhoto = require '../../models/photo'
RestController = require 'backbone-rest'

module.exports = class PhotosController extends RestController

  route: 'photos'
  model_type: ServerPhoto

  constructor: (app) ->
    super
