Backbone = require 'backbone'
Classroom = require './classroom'

module.exports = class Classrooms extends Backbone.Collection
  model: Classroom