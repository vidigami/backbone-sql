BackboneRelational = require './backbone_relational'

module.exports = class SequelizeBackboneAdapter
  # todo: relations

  @modelFindQuery: (model) -> return {where: {id: model.get('id')}}

  @nativeToModel: (sequelize_model, model_type) ->
    return if not sequelize_model

    # work around for Backbone Relational
    model = BackboneRelational.findOrCreate(model_type, (new model_type()).parse(@nativeToAttributes(doc)))
    model._db_model = sequelize_model
    return model

  @nativeToAttributes: (sequelize_model, attributes={}) ->
    return if not sequelize_model
    (attributes[key] = value) for own key, value of sequelize_model when key in sequelize_model.attributes
    return attributes

  @attributesToNative: (attributes, sequelize_model) ->
    return if not sequelize_model
    (sequelize_model[key] = null) for own key, value of sequelize_model when key in sequelize_model.attributes
    sequelize_model[key] = value for key, value in attributes
    return sequelize_model
