util = require 'util'
assert = require 'assert'
_ = require 'underscore'
Backbone = require 'backbone'
BackboneORM = require 'backbone-orm'
{Queue, Utils} = BackboneORM
{ModelCache} = BackboneORM.CacheSingletons

option_sets = require('backbone-orm/test/option_sets')
parameters = __test__parameters if __test__parameters?
_.each option_sets, exports = (options) ->
  return if options.embed
  options = _.extend({}, options, parameters) if parameters

  DATABASE_URL = options.database_url or ''
  SLAVE_DATABASE_URL = "#{DATABASE_URL}_slave"
  BASE_SCHEMA = options.schema or {}
  SYNC = options.sync

  describe "Sql master slave selection #{options.$parameter_tags or ''}#{options.$tags}", ->

    Flat = null
    before ->
      class Flat extends Backbone.Model
        urlRoot: "#{DATABASE_URL}/flats"
        schema: _.extend BASE_SCHEMA,
          a_string: 'String'
        sync: SYNC(Flat, {slaves: [SLAVE_DATABASE_URL]})
    after (callback) ->
      queue = new Queue()
      queue.defer (callback) -> ModelCache.reset(callback)
      queue.defer (callback) -> Utils.resetSchemas [Flat], callback
      queue.await callback
    after -> Flat = null

    beforeEach (callback) ->
      queue = new Queue(1)
      queue.defer (callback) -> ModelCache.configure({enabled: !!options.cache, max: 100}, callback)
      queue.defer (callback) -> Utils.resetSchemas [Flat], callback
      queue.await callback

    # TODO: This is wrong, maybe a way to force read from slave is needed
    it.skip 'Writes to the master database', (done) ->
      flat = new Flat({a_string: 'hello'})
      flat.save {}, (err, saved) ->
        assert.ok(!err, "No errors: #{err}")

        Flat.findOne (err, shouldnt_exist) ->
          assert.ok(!err, "No errors: #{err}")
          assert.ok(!shouldnt_exist, "Read from slave database (model not found)")

          done()
