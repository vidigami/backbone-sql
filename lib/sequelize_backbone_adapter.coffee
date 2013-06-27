util = require 'util'
_ = require 'underscore'

module.exports = class SequelizeBackboneAdapter
  # todo: relations

  @nativeToModel: (seq_model, model_type) ->
    model = new model_type()
    if seq_model
      model = model.set(model.parse(@nativeToAttributes(seq_model)))
      model._seq_model = seq_model
    return model

  @nativeToAttributes: (seq_model) ->
    # TODO: handle relationship mapping
    attributes = {}
    for key in seq_model.attributes
      if _.isUndefined(seq_model[key])
        attributes[key] = null
      else
        attributes[key] = seq_model[key]
    return attributes

  @attributesToNative: (attributes) ->
    # TODO: handle relationship mapping
    return attributes
