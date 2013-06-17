util = require 'util'
_ = require 'underscore'
Queue = require 'queue-async'

JSONUtils = require 'backbone-orm/lib/json_utils'
Fabricator = require 'backbone-orm/fabricator'
Album = require '../models/album'
Photo = require '../models/photo'

BASE_COUNT = 10

test_parameters =
  model_type: Album
  route: 'albums'
  beforeEach: (callback) ->
    MODELS = {}
    queue = new Queue(1)

    # destroy all
    queue.defer (callback) ->
      destroy_queue = new Queue()

      destroy_queue.defer (callback) -> Album.destroy callback
      destroy_queue.defer (callback) -> Photo.destroy callback

      destroy_queue.await callback

    # create all
    queue.defer (callback) ->
      create_queue = new Queue()

      create_queue.defer (callback) -> Fabricator.create(Album, BASE_COUNT, {
        name: Fabricator.uniqueId('album_')
        created_at: Fabricator.date
        updated_at: Fabricator.date
      }, (err, models) -> MODELS.photos = models; callback(err))

      create_queue.defer (callback) -> Fabricator.create(Photo, BASE_COUNT, {
        name: Fabricator.uniqueId('photo_')
        created_at: Fabricator.date
        updated_at: Fabricator.date
      }, (err, models) -> MODELS.albums = models; callback(err))

      create_queue.await callback

    # link and save all
    queue.defer (callback) ->
      save_queue = new Queue()

      albums = MODELS.albums.slice(0)
      for photo in MODELS.photos
        do (photo) ->
          album = albums.pop()
          photo.set({album: album})
          save_queue.defer (callback) -> photo.save {}, adapters.bbCallback callback

      for album in MODELS.albums
        do (album) ->
          save_queue.defer (callback) -> album.save {}, adapters.bbCallback callback

      save_queue.await callback

    queue.await (err) ->
      console.log '?'
      callback(null, []) #_.map(MODELS.photos, (test) -> JSONUtils.valueToJSON(test.toJSON())))


#require('backbone-orm/lib/test_generators/all_flat')(test_parameters)
#require('backbone-rest/lib/test_generators/all')(test_parameters)

require('backbone-orm/lib/test_generators/relational/has_many')(test_parameters)
