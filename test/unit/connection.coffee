assert = require 'assert'
Backbone = require 'backbone'
Sequelize = require 'sequelize'

queries = require '../config/queries'

Photo = require '../../models/photo'
Album = require '../../models/album'


describe 'Model methods', ->


  it 'Handles a limit query', (done) ->
    Photo.find queries.limit, (err, models) ->
      assert.ok(!err, 'no errors')
      assert.equal(models.length, queries.limit.$limit, 'found the right number of models')
      done()


  it 'Handles a count query', (done) ->
    Photo.cursor queries.count, (err, cursor) ->
      assert.ok(!err, 'no errors')
      assert.ok(cursor.getValue(), 'has a count')
      done()


  it 'Handles a find id query', (done) ->
    Photo.find queries.photo_id.id, (err, model) ->
      assert.ok(!err, 'no errors')
      assert.ok(model, 'gets a model')
      assert.equal(model.get('id'), queries.photo_id.id, 'model has the correct id')
      done()


  it 'Handles another find id query', (done) ->
    Album.find queries.album_id.id, (err, model) ->
      assert.ok(!err, 'no errors')
      assert.ok(model, 'gets a model')
      assert.equal(model.get('id'), queries.album_id.id, 'model has the correct id')
      done()


  it 'Handles a find by query id', (done) ->
    Photo.find queries.photo_id, (err, models) ->
      assert.ok(!err, 'no errors')
      assert.ok(models.length, 'gets models')
      done()


  it 'Handles a name find query', (done) ->
    Album.find queries.album_name, (err, models) ->
      assert.ok(!err, 'no errors')
      assert.ok(models.length, 'gets models')
      for model in models
        assert.equal(model.get('name'), queries.album_name.name, 'model has the correct name')
      done()


  it 'Handles a name find query', (done) ->
    Album.find queries.album_name, (err, models) ->
      assert.ok(!err, 'no errors')
      assert.ok(models, 'gets models')
      for model in models
        assert.equal(model.get('name'), queries.album_name.name, 'model has the correct name')
      done()


  it 'Handles a select fields query', (done) ->
    Album.find queries.select, (err, models) ->
      assert.ok(!err, 'no errors')
      assert.ok(models, 'gets models')
      for model in models
        assert.equal(model.attributes.length, queries.select.$fields.length, 'gets only the requested values')
      done()


  it 'Cursor makes json', (done) ->
    Album.cursor queries.album_name, (err, cursor) ->
      assert.ok(!err, 'no errors')
      assert.ok(cursor, 'gets a cursor')
      cursor.toJSON() (err, json) ->
        assert.ok(!err, 'no errors')
        assert.ok(json, 'cursor toJSON gives us json')
        assert.ok(json.length, 'json is an array with a length')
        done()


  it 'Cursor makes models', (done) ->
    Album.cursor queries.album_name, (err, cursor) ->
      assert.ok(!err, 'no errors')
      assert.ok(cursor, 'gets a cursor')
      cursor.toModels() (err, models) ->
        assert.ok(!err, 'no errors')
        assert.ok(models, 'cursor toModels gives us models')
        for model in models
          assert.ok(model.constructor is Album, 'model is the correct type')
        done()


  it 'Cursor can chain limit', (done) ->
    limit = 3
    Album.cursor queries.album_name, (err, cursor) ->
      assert.ok(!err, 'no errors')
      assert.ok(cursor, 'gets a cursor')
      cursor.limit(limit).toModels() (err, models) ->
        assert.ok(!err, 'no errors')
        assert.ok(models, 'cursor toModels gives us models')
        assert.equal(models.length, limit, 'found models')
        done()


  it 'Cursor can chain limit and offset', (done) ->
    limit = offset = 3
    Album.cursor queries.album_name, (err, cursor) ->
      assert.ok(!err, 'no errors')
      assert.ok(cursor, 'gets a cursor')
      cursor.limit(limit).offset(offset).toModels() (err, models) ->
        assert.ok(!err, 'no errors')
        assert.ok(models, 'cursor toModels gives us models')
        assert.equal(models.length, limit, 'found models')
        done()


  it 'Cursor can select fields', (done) ->
    Album.cursor queries.album_name, (err, cursor) ->
      assert.ok(!err, 'no errors')
      assert.ok(cursor, 'gets a cursor')
      cursor.select(queries.select.$fields).toModels() (err, models) ->
        assert.ok(!err, 'no errors')
        assert.ok(models, 'cursor toModels gives us models')
        for model in models
          assert.equal(model.attributes.length, queries.select.$fields.length, 'gets only the requested values')
        done()


  it 'Cursor can select values', (done) ->
    Album.cursor queries.album_name, (err, cursor) ->
      assert.ok(!err, 'no errors')
      assert.ok(cursor, 'gets a cursor')
      cursor.select(queries.select.$fields).values() (err, values) ->
        assert.ok(!err, 'no errors')
        assert.ok(Array.isArray(values), 'cursor values is an array')
        done()


  it 'Saves an album', (done) ->
    album = new Album({name: 'Bob'})
    album.save (err, model) ->
      assert.ok(!err, 'no errors')
      assert.ok(model, 'made a model')
      assert.equal(models[0].get('name'), 'Bob', 'model is Bob')
      done()

