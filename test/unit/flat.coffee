util = require 'util'
_ = require 'underscore'
Backbone = require 'backbone'
Queue = require 'queue-async'

JSONUtils = require 'backbone-orm/lib/json_utils'
Fabricator = require 'backbone-orm/fabricator'

BASE_COUNT = 10

class FlatModel extends Backbone.Model
  @schema:
    name: ['String', indexed: true]
    created_at: 'Date'
    updated_at: 'Date'

  url: "#{require('../config/database')['test']}/flats"
  sync: require('../../backbone_sync')(FlatModel)

test_parameters =
  model_type: FlatModel
  route: 'mock_models'
  beforeEach: (callback) ->
    queue = new Queue(1)
    queue.defer (callback) -> FlatModel.destroy callback
    queue.defer (callback) -> Fabricator.create(FlatModel, 10, {
      name: Fabricator.uniqueId('flat_')
      created_at: Fabricator.date
      updated_at: Fabricator.date
    }, callback)
    queue.await (err) -> callback(null, _.map(_.toArray(arguments).pop(), (test) -> test.toJSON()))

require('backbone-orm/lib/test_generators/all_flat')(test_parameters)
