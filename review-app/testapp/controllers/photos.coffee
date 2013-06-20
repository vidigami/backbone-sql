logger = require '../../node/logger'
ServerPhoto = require '../../models/photo'
RestController = require 'backbone-rest'
Utils = require 'backbone-orm/utils'

module.exports = class PhotosController extends RestController

  route: 'photos'
  model_type: ServerPhoto

  constructor: (app) ->
    super

  index: (req, res) =>
    try
      console.log Utils.parse(req.query)
      cursor = @model_type.cursor(Utils.parse(req.query))
      cursor = cursor.whiteList(@white_lists.index) if @white_lists.index
      cursor.toJSON (err, json) ->
        if err then res.send(404) else res.json(json)
    catch err
      res.status(500).send(error: err.toString())
