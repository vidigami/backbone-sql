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
    flat: -> ['hasOne', Flat]
    reverse: -> ['hasOne', Reverse]
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
      }, (err, models) -> MODELS.flat = models; callback(err))

      create_queue.defer (callback) -> Fabricator.create(Owner, BASE_COUNT, {
        name: Fabricator.uniqueId('owner_')
      }, (err, models) -> MODELS.owner = models; callback(err))

      create_queue.defer (callback) -> Fabricator.create(Reverse, BASE_COUNT, {
        name: Fabricator.uniqueId('reverse_')
      }, (err, models) -> MODELS.reverse = models; callback(err))

      create_queue.await callback

    # link and save all
    queue.defer (callback) ->
      save_queue = new Queue()

      for owner, index in MODELS.owner
        do (owner) ->
          owner.set({flat: MODELS.flat[index], reverse: MODELS.reverse[index]})
          save_queue.defer (callback) -> owner.save {}, adapters.bbCallback callback

      for flat in MODELS.flat
        do (flat) ->
          save_queue.defer (callback) -> flat.save {}, adapters.bbCallback callback

      for reverse in MODELS.reverse
        do (reverse) ->
          save_queue.defer (callback) -> reverse.save {}, adapters.bbCallback callback

      save_queue.await callback

    queue.await (err) ->
      callback(null, MODELS.owner)


require('backbone-orm/lib/test_generators/relational/has_one')(test_parameters)

