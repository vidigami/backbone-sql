_ = require 'underscore'
inflection = require 'inflection'
Sequelize = require 'sequelize'

module.exports = class RelationParser

  constructor: (@model_type, @raw_relations) ->

  relation_types: ['hasOne', 'hasMany']

  parse: ->
    @relations = {}
    for name, relation_options of @raw_relations
      relation_options = _.result(@raw_relations, name)
      return (console.log 'Error: parseRelations, relation does not resolve to an array of [type, model, options]', relation_options) if not Array.isArray(relation_options)

      type = relation_options[0]
      model = relation_options[1]
      options = _.reduce(relation_options.slice(2), ((k,v) -> _.extend(k, v)), {})

      @relations[name] =
        type: type
        model: model
        options: _.extend(
          as: name
          foreignKey: @_keyFromTypeAndModel(type, model)
          , options)
    return @

  _keyFromTypeAndModel: (type, model) ->
    if type is 'hasOne'
      return inflection.foreign_key(model._sync.model_name)
    if type is 'hasMany'
      return inflection.foreign_key(@model_type._sync.model_name)
