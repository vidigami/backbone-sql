_ = require 'underscore'

MODEL_PATHS = [
  '../models/photo',
  '../models/album'
]

#model.prototype.sync('initialize') for model in _.map(MODEL_PATHS, (test) -> require(test))

model.initialize() for model in _.map(MODEL_PATHS, (test) -> require(test))
