util = require 'util'
_ = require 'underscore'
Backbone = require 'backbone'
Queue = require 'queue-async'

JSONUtils = require 'backbone-orm/lib/json_utils'
Fabricator = require 'backbone-orm/fabricator'
Utils = require 'backbone-orm/utils'
adapters = Utils.adapters

BASE_COUNT = 1

class Flat extends Backbone.Model
  @schema:
    name: 'String'
    owner: -> ['belongsTo', Owner]
  url: "#{require('../config/database')['test']}/flats"
  sync: require('../../backbone_sync')(Flat)

class Reverse extends Backbone.Model
  @schema:
    name: 'String'
    owner: -> ['belongsTo', Owner]
  url: "#{require('../config/database')['test']}/reverses"
  sync: require('../../backbone_sync')(Reverse)

class Owner extends Backbone.Model
  @schema:
    name: 'String'
    flats: -> ['hasMany', Flat]
    reverses: -> ['hasMany', Reverse]
  url: "#{require('../config/database')['test']}/owners"
  sync: require('../../backbone_sync')(Owner)

test_parameters =
  model_type: Owner
  route: 'owners'
  beforeEach: (callback) ->
    MODELS = {}
    queue = new Queue(1)

    # destroy all
    queue.defer (callback) ->
      destroy_queue = new Queue()

      destroy_queue.defer (callback) -> Flat.destroy callback
      destroy_queue.defer (callback) -> Owner.destroy callback
      destroy_queue.defer (callback) -> Reverse.destroy callback

      destroy_queue.await callback

    # create all
    queue.defer (callback) ->
      create_queue = new Queue()

      create_queue.defer (callback) -> Fabricator.create(Flat, BASE_COUNT, {
        name: Fabricator.uniqueId('flat_')
      }, (err, models) -> MODELS.flats = models; callback(err))

      create_queue.defer (callback) -> Fabricator.create(Owner, BASE_COUNT, {
        name: Fabricator.uniqueId('owner_')
      }, (err, models) -> MODELS.owners = models; callback(err))

      create_queue.defer (callback) -> Fabricator.create(Reverse, BASE_COUNT, {
        name: Fabricator.uniqueId('reverse_')
      }, (err, models) -> MODELS.reverses = models; callback(err))

      create_queue.await callback

    # link and save all
    queue.defer (callback) ->
      save_queue = new Queue()

      owners = MODELS.owners.slice(0)
      for flat in MODELS.flats
        do (flat) ->
          owner = owners.pop()
          flat.set({owner: owner})
          save_queue.defer (callback) -> flat.save {}, adapters.bbCallback callback

      owners = MODELS.owners.slice(0)
      for reverse in MODELS.reverses
        do (reverse) ->
          owner = owners.pop()
          reverse.set({owner: owner})
          save_queue.defer (callback) -> reverse.save {}, adapters.bbCallback callback

      for owner in MODELS.owners
        do (owner) ->
          save_queue.defer (callback) -> owner.save {}, adapters.bbCallback callback

      save_queue.await callback

    queue.await (err) ->
      callback(null, _.map(MODELS.reverses, (test) -> JSONUtils.valueToJSON(test.toJSON())))


require('backbone-orm/lib/test_generators/relational/has_many')(test_parameters)
