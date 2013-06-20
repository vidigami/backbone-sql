logger = require 'vidigami/node/logger'
ServerAlbum = require '../../models/album'
RestController = require 'backbone-rest'

module.exports = class AlbumsController extends RestController

  route: 'albums'
  model_type: ServerAlbum

  constructor: (app, options={}) ->
    super
    app.get "/#{@route}/:id/photos", @photos

  photos: (req, res) =>
    try
      @model_type.find req.params.id, (err, album) =>
        return res.status(500).send(error: err.toString()) if err
        return res.status(404).send("Album not found with id: #{req.params.id}") unless album
        album.get 'photos', (err, json) ->
          if err then res.send(404) else res.json(json)
    catch err
      res.status(500).send(error: err.toString())
