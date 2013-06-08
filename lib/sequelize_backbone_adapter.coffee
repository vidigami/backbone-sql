BackboneRelationalUtils = require 'backbone-node/lib/backbone_relational_utils'

module.exports = class SequelizeBackboneAdapter
  # todo: relations

  @nativeToModel: (seq_model, model_type) ->
    return if not seq_model

    # work around for Backbone Relational
    model = BackboneRelationalUtils.findOrCreate(model_type, model_type::parse(@nativeToAttributes(seq_model)))
    model._db_model = seq_model
    return model

  @nativeToAttributes: (seq_model) ->
    # TODO: handle relationship mapping
    attributes = {}
    attributes[key] = seq_model[key] for key in seq_model.attributes
    return attributes

  @attributesToNative: (attributes) ->
    # TODO: handle relationship mapping
    return attributes
