util = require 'util'
assert = require 'assert'
_ = require 'underscore'
Backbone = require 'backbone'
Queue = require 'backbone-orm/lib/queue'

Utils = require 'backbone-orm/lib/utils'
bbCallback = Utils.bbCallback

module.exports = (options, callback) ->
  DATABASE_URL = options.database_url or ''
  SLAVE_DATABASE_URL = "#{DATABASE_URL}_slave"
  BASE_SCHEMA = options.schema or {}
  SYNC = options.sync

  class Flat extends Backbone.Model
    urlRoot: "#{DATABASE_URL}/flats"
    @schema: _.extend BASE_SCHEMA,
      a_string: 'String'
    sync: SYNC(Flat, {slaves: [SLAVE_DATABASE_URL]})

  describe "Sql master slave selection", ->

    before (done) -> return done() unless options.before; options.before([Flat], done)
    after (done) -> callback(); done()
    beforeEach (done) ->
      queue = new Queue(1)
      for model_type in [Flat]
        do (model_type) -> queue.defer (callback) ->
          db = model_type.db()
          db.resetSchema callback
      queue.await done

    it 'Writes to the master database', (done) ->
      flat = new Flat({a_string: 'hello'})
      flat.save {}, (err, saved) ->
        assert.ok(!err, "No errors: #{err}")

        Flat.findOne (err, shouldnt_exist) ->
          assert.ok(!err, "No errors: #{err}")
          assert.ok(!shouldnt_exist, "Read from slave database (model not found)")

          done()
