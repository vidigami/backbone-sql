logger = require '../../node/logger'
ServerPhoto = require '../../models/photo'
RestController = require './rest_controller'

module.exports = class PhotosController extends RestController

  route: 'photos'
  model_type: ServerPhoto

  constructor: (app) ->
    super

  show: (req, res) =>
    id = req.params.id
    logger.info("Get id: #{id}")
    @model_type.findOne id, (err, photo) ->
      return res.json({ error: err }) if err
      return res.status(404).json() if not photo
#      console.log photo
      logger.info(photo)
      res.json(photo.attributes)
