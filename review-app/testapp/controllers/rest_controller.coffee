_ = require 'underscore'
logger = require 'vidigami/node/logger'
#
#HTTP_ERRORS =
#  INTERNAL_SERVER: 500

module.exports = class RESTController

  parse_json: true
  route: ''
  cors:
    enabled: true
    origins: '*'

  model_type: null

  constructor: (app) ->
    @_enableCors(app, url) for url in [@route, "#{@route}/:id"] if @cors.enabled
    @_bindDefaultRoutes(app)

  index: (req, res) =>
    query = req.params
    logger.info("Get index, query: #{query}")
    @model_type.find query, (err, photos) ->
      return res.json({ error: err }) if err
      res.json(photo.attributes for photo in photos)

  show: (req, res) =>
    id = req.params.id
    logger.info("Get id: #{id}")
    @model_type.findOne id, (err, photo) ->
      return res.json({ error: err }) if err
      return res.status(404).json() if not photo
      res.json(photo.attributes)

  create: (req, res) =>
    @model_type.create new @model_type(req.params), (err, photo) ->
      return res.json({ error: err }) if err
      return res.status(404).json() if not photo
      res.json(photo.attributes)

  update: (req, res) =>
    @model_type.update new @model_type(req.params), (err, photo) ->
      return res.json({ error: err }) if err
      return res.status(404).json() if not photo
      res.json(photo.attributes)

  delete: (req, res) =>
    id = req.params.id
    @model_type.delete new @model_type(req.params), (err, photo) ->
      return res.json({ error: err }) if err
      return res.status(404).json() if not photo
      res.json(photo.attributes)

  _enableCors: (app, url) =>
    app.all url, (req, res, next) ->
      res.set 'Access-Control-Allow-Origin', cors.origins if cors.origins
      res.header 'Access-Control-Allow-Headers', 'X-Requested-With,Content-Disposition,Content-Type,Content-Description,Content-Range'
      res.header 'Access-Control-Allow-Methods', 'HEAD, GET, POST, PUT, DELETE, OPTIONS'
      res.header('Access-Control-Allow-Credentials', 'true')
      next()

  _bindDefaultRoutes: (app) =>
    app.get "/#{@route}", @index
    app.get "/#{@route}/:id", @show
    app.post "/#{@route}", @create
    app.put "/#{@route}/:id", @update
    app.delete "/#{@route}/:id", @delete

  _wtf: ->