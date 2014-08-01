util = require 'util'
assert = require 'assert'

BackboneORM = require 'backbone-orm'
{_, Backbone, Queue, Utils} = BackboneORM

_.each BackboneORM.TestUtils.optionSets(), exports = (options) ->
  options = _.extend({}, options, __test__parameters) if __test__parameters?
  return if options.embed

  DATABASE_URL = options.database_url or ''
  SLAVE_DATABASE_URL = "#{DATABASE_URL}_slave"
  BASE_SCHEMA = options.schema or {}
  SYNC = options.sync

  describe "Sql master slave selection #{options.$parameter_tags or ''}#{options.$tags}", ->
    Flat = null
    before ->
      BackboneORM.configure {model_cache: {enabled: !!options.cache, max: 100}}

      class Flat extends Backbone.Model
        urlRoot: "#{DATABASE_URL}/flats"
        schema: _.extend BASE_SCHEMA,
          a_string: 'String'
        sync: SYNC(Flat, {slaves: [SLAVE_DATABASE_URL]})

    after (callback) -> Utils.resetSchemas [Flat], callback
    beforeEach (callback) -> Utils.resetSchemas [Flat], callback

    # TODO: This is wrong, maybe a way to force read from slave is needed
    it.skip 'Writes to the master database', (done) ->
      flat = new Flat({a_string: 'hello'})
      flat.save (err, saved) ->
        assert.ok(!err, "No errors: #{err}")

        Flat.findOne (err, shouldnt_exist) ->
          assert.ok(!err, "No errors: #{err}")
          assert.ok(!shouldnt_exist, "Read from slave database (model not found)")

          done()
