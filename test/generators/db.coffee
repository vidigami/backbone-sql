util = require 'util'
assert = require 'assert'
_ = require 'underscore'
Backbone = require 'backbone'
Queue = require 'queue-async'

Utils = require 'backbone-orm/lib/utils'
bbCallback = Utils.bbCallback

runTests = (options, callback) ->
  DATABASE_URL = options.database_url or ''
  BASE_SCHEMA = options.schema or {}
  SYNC = options.sync

  class Flat extends Backbone.Model
    urlRoot: "#{DATABASE_URL}/flats"
    @schema: _.extend BASE_SCHEMA,
      a_string: 'String'
    sync: SYNC(Flat)

  describe "Sql db tools", ->

    before (done) -> return done() unless options.before; options.before([Flat], done)
    after (done) -> callback(); done()
    beforeEach (done) ->
      db = Flat.db()
      db.dropTableIfExists done

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

      done()

    it 'Can reset a single relation', (done) ->
      done()


# each model should have available attribute 'id', 'name', 'created_at', 'updated_at', etc....
# beforeEach should return the models_json for the current run
module.exports = (options, callback) ->
  queue = new Queue(1)
  queue.defer (callback) -> runTests(options, callback)
  queue.await callback
