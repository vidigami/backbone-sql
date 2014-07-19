util = require 'util'
assert = require 'assert'

BackboneORM = require 'backbone-orm'
{_, Backbone, Queue, Utils} = BackboneORM

option_sets = require('backbone-orm/test/option_sets')
parameters = __test__parameters if __test__parameters?
_.each option_sets, exports = (options) ->
  return if options.embed
  options = _.extend({}, options, parameters) if parameters

  DATABASE_URL = options.database_url or ''
  BASE_SCHEMA = options.schema or {}
  SYNC = options.sync


  describe "Sql db tools #{options.$parameter_tags or ''}#{options.$tags}", ->
    Flat = Reverse = Owner = null
    before ->
      class Flat extends Backbone.Model
        urlRoot: "#{DATABASE_URL}/flats"
        schema: _.extend BASE_SCHEMA,
          a_string: 'String'
        sync: SYNC(Flat)

      class Reverse extends Backbone.Model
        urlRoot: "#{DATABASE_URL}/reverses"
        schema: _.defaults({
          owner: -> ['belongsTo', Owner]
          another_owner: -> ['belongsTo', Owner, as: 'more_reverses']
          many_owners: -> ['hasMany', Owner, as: 'many_reverses']
        }, BASE_SCHEMA)
        sync: SYNC(Reverse)

      class Owner extends Backbone.Model
        urlRoot: "#{DATABASE_URL}/owners"
        schema: _.defaults({
          a_string: 'String'
          flats: -> ['hasMany', Flat]
          reverses: -> ['hasMany', Reverse]
          more_reverses: -> ['hasMany', Reverse, as: 'another_owner']
          many_reverses: -> ['hasMany', Reverse, as: 'many_owners']
        }, BASE_SCHEMA)
        sync: SYNC(Owner)

    after (callback) ->
      queue = new Queue()
      queue.defer (callback) -> BackboneORM.model_cache.reset(callback)
      queue.defer (callback) -> Utils.resetSchemas [Flat], callback
      queue.await callback
    after -> Flat = Reverse = Owner = null

    beforeEach (callback) ->
      queue = new Queue(1)
      queue.defer (callback) -> BackboneORM.configure({model_cache: {enabled: !!options.cache, max: 100}}, callback)
      queue.defer (callback) -> Utils.resetSchemas [Flat], callback
      for model_type in [Flat, Reverse, Owner]
        do (model_type) -> queue.defer (callback) -> model_type.db().dropTableIfExists callback
      queue.await callback

    it.skip 'Can drop a models table', (done) ->
      db = Flat.db()
      db.resetSchema (err) ->
        assert.ok(!err, "No errors: #{err}")
        db.dropTable (err) ->
          assert.ok(!err, "No errors: #{err}")
          db.hasTable (err, has_table) ->
            assert.ok(!err, "No errors: #{err}")
            assert.ok(!has_table, "Table removed: #{has_table}")
            done()

    it.skip 'Can reset a models schema', (done) ->
      db = Flat.db()
      db.dropTableIfExists (err) ->
        assert.ok(!err, "No errors: #{err}")
        db.resetSchema (err) ->
          assert.ok(!err, "No errors: #{err}")
          db.hasColumn 'a_string', (err, has_column) ->
            assert.ok(!err, "No errors: #{err}")
            assert.ok(has_column, "Has the test column: #{has_column}")
            done()

    it.skip 'Can ensure a models schema', (done) ->
      db = Flat.db()
      db.dropTableIfExists (err) ->
        assert.ok(!err, "No errors: #{err}")
        db.ensureSchema (err) ->
          assert.ok(!err, "No errors: #{err}")
          db.hasColumn 'a_string', (err, has_column) ->
            assert.ok(!err, "No errors: #{err}")
            assert.ok(has_column, "Has the test column: #{has_column}")
            done()

    it.skip 'Can add a column to the db', (done) ->
      db = Flat.db()
      db.createTable().addColumn('test_column', 'string').end (err) ->
        assert.ok(!err, "No errors: #{err}")
        db.hasColumn 'test_column', (err, has_column) ->
          assert.ok(!err, "No errors: #{err}")
          assert.ok(has_column, "Has the test column: #{has_column}")
          done()

    it.skip 'Can reset a single relation', (done) ->
      console.log 'TODO'
      done()

    it 'Can ensure many to many models schemas', (done) ->
      reverse_db = Reverse.db()
      owner_db = Owner.db()

      drop_queue = new Queue(1)

      drop_queue.defer (callback) ->
        reverse_db.dropTableIfExists (err) ->
          assert.ok(!err, "No errors: #{err}")
          callback()

      drop_queue.defer (callback) ->
        owner_db.dropTableIfExists (err) ->
          assert.ok(!err, "No errors: #{err}")
          callback()

      drop_queue.await (err) ->
        assert.ok(!err, "No errors: #{err}")

        queue = new Queue(1)

        queue.defer (callback) ->
          reverse_db.ensureSchema (err) ->
            assert.ok(!err, "No errors: #{err}")
            callback()

        queue.defer (callback) ->
          owner_db.ensureSchema (err) ->
            assert.ok(!err, "No errors: #{err}")
            callback()

        queue.await (err) ->
          assert.ok(!err, "No errors: #{err}")
          owner_db.hasColumn 'a_string', (err, has_column) ->
            assert.ok(!err, "No errors: #{err}")
            assert.ok(has_column, "Has the test column: #{has_column}")
            done()
