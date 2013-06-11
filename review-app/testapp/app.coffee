express = require 'express'
http = require 'http'
path = require 'path'

init = require './initialize'
config = require './config'
bind_options =
  origins: config.origins()
  auth: express.basicAuth('root', 'temppass2013')

app = express()
app.configure ->
  app.set "port", config.port()
  app.use express.favicon()
  app.use express.logger("dev")
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use app.router
  app.use express.static(path.join(__dirname, "../public"))

app.configure 'development', ->
  app.use express.errorHandler()

#########################
# Monitor Status
#########################
app.get '/status/server', express.basicAuth('dvidi', 'B8BnxkbL'), (req, res) -> res.json({ok: true})

#########################
# Components
#########################

cross_origin = require 'vidigami/node/cross_origin'
PhotosController = require './controllers/photos'
AlbumsController = require './controllers/albums'


cross_origin.allowOriginAllPaths(app, bind_options)

photos_controller = new PhotosController(app)
albums_controller = new AlbumsController(app)


# start the server!
http.createServer(app).listen app.get("port"), -> console.log("Express server listening on port " + app.get("port"))
