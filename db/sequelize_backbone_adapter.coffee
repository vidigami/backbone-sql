
module.exports = class SequelizeBackboneAdapter
  # todo: relations

  sequelizeToModel: (sequelize_model, model_type) ->
    return if not sequelize_model
    model = new model_type(@sequelizeToAttributes(sequelize_model))
    model._db_model = sequelize_model
    return model

  sequelizeToAttributes: (sequelize_model, attributes={}) ->
    return if not sequelize_model
    (attributes[attr] = val) for own attr, val of  sequelize_model when attr in sequelize_model.attributes
    return attributes

  attributesToSequelize: (attributes, sequelize_model) ->
    return if not sequelize_model
    (sequelize_model[attr] = null) for own attr, val of  sequelize_model when attr in sequelize_model.attributes
    sequelize_model[attr] = val for attr, val in attributes
    return sequelize_model
