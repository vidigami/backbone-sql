_ = require 'underscore'
inflection = require 'inflection'
Sequelize = require 'sequelize'

module.exports = class RelationParser
  @relation_types: ['hasOne', 'hasMany']

  @parse: (model_type, raw_relations) ->
    result = {}
    for name, relation_options of raw_relations
      relation_options = _.result(raw_relations, name)
      return (console.log 'Error: parseRelations, relation does not resolve to an array of [type, model, options]', relation_options) if not _.isArray(relation_options)

      relation_type = relation_options[0]
      model = relation_options[1]
      options = _.reduce(relation_options.slice(2), ((k,v) -> _.extend(k, v)), {})

      result[name] = @create_parsed_relation(name, model_type, relation_type, model, options)

    return result

  @create_parsed_relation: (name, model_type, relation_type, model, options) ->
    type: relation_type
    model: model_type
    options: _.extend(
        as: name
        foreignKey: @_keyFromTypeAndModel(relation_type, model_type, model)
      , options)

  @_keyFromTypeAndModel: (relation_type, from_model, to_model) ->
    if relation_type is 'hasOne'
      return inflection.foreign_key(from_model._sync.model_name)
    if relation_type is 'hasMany'
      return inflection.foreign_key(to_model._sync.model_name)
