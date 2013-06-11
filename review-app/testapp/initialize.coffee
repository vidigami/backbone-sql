_ = require 'underscore'

MODEL_PATHS = [
  '../models/photo',
  '../models/album'
]

model.initialize() for model in _.map(MODEL_PATHS, (test) -> require(test))
