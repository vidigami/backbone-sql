util = require 'util'
assert = require 'assert'
_ = require 'underscore'
Backbone = require 'backbone'
Queue = require 'backbone-orm/lib/queue'

module.exports = (options, callback) ->
  DATABASE_URL = options.database_url or ''
  BASE_SCHEMA = options.schema or {}
  SYNC = options.sync

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
    }, BASE_SCHEMA)
    sync: SYNC(Reverse)

  class Owner extends Backbone.Model
    urlRoot: "#{DATABASE_URL}/owners"
    schema: _.defaults({
      flats: -> ['hasMany', Flat]
      reverses: -> ['hasMany', Reverse]
      more_reverses: -> ['hasMany', Reverse, as: 'another_owner']
    }, BASE_SCHEMA)
    sync: SYNC(Owner)

  describe "Sql db tools", ->

    before (done) -> return done() unless options.before; options.before([Flat], done)
    after (done) -> callback(); done()
    beforeEach (done) ->
      queue = new Queue(1)
      for model_type in [Flat, Reverse, Owner]
        do (model_type) -> queue.defer (callback) ->
          db = model_type.db()
          db.dropTableIfExists callback
      queue.await done

    it 'Can drop a models table', (done) ->
      db = Flat.db()
      db.resetSchema (err) ->
        assert.ok(!err, "No errors: #{err}")
        db.dropTable (err) ->
          assert.ok(!err, "No errors: #{err}")
          db.hasTable (err, has_table) ->
            assert.ok(!err, "No errors: #{err}")
            assert.ok(!has_table, "Table removed: #{has_table}")
            done()

    it 'Can reset a models schema', (done) ->
      db = Flat.db()
      db.dropTableIfExists (err) ->
        assert.ok(!err, "No errors: #{err}")
        db.resetSchema (err) ->
          assert.ok(!err, "No errors: #{err}")
          db.hasColumn 'a_string', (err, has_column) ->
            assert.ok(!err, "No errors: #{err}")
            assert.ok(has_column, "Has the test column: #{has_column}")
            done()

    it 'Can ensure a models schema', (done) ->
      db = Flat.db()
      db.dropTableIfExists (err) ->
        assert.ok(!err, "No errors: #{err}")
        db.ensureSchema (err) ->
          assert.ok(!err, "No errors: #{err}")
          db.hasColumn 'a_string', (err, has_column) ->
            assert.ok(!err, "No errors: #{err}")
            assert.ok(has_column, "Has the test column: #{has_column}")
            done()

    it 'Can add a column to the db', (done) ->
      db = Flat.db()
      db.createTable().addColumn('test_column', 'string').end (err) ->
        assert.ok(!err, "No errors: #{err}")
        db.hasColumn 'test_column', (err, has_column) ->
          assert.ok(!err, "No errors: #{err}")
          assert.ok(has_column, "Has the test column: #{has_column}")
          done()

    it 'Can reset a single relation', (done) ->
      console.log 'TODO'
      done()
