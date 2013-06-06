assert = require 'assert'

Backbone = require 'backbone'

Sequelize = require 'sequelize'
sequelize = require '../../config/sequelize'
BackboneSequelize = require '../../../db/backbone_sequelize'

Photo = require '../../../photo'
Photo = require '../../../album'

module.exports = class QueryThing extends Backbone.Model
  sync: new BackboneSync({database_config: require('../config/database')['test'], collection: 'query_things', model: QueryThing})

describe "Query", ->

  # TODO: before delete the collection

  it "finds an object", (done) ->
    thing = new QueryThing({name: 'Bob'})
    thing.save {}, {
    success: ->
      query = new Query(QueryThing, {name: 'Bob'})
      query.toModels (err, models) ->
        assert.ok(!err, 'no errors')
        assert.ok(models.length, 'found models')
        assert.equal(models[0].get('name'), 'Bob', 'model is Bob')

        done()
    }