util = require 'util'
_ = require 'underscore'
Knex = require 'knex'

Cursor = require 'backbone-orm/lib/cursor'

COMPARATORS =
  $lt: '<'
  $lte: '<='
  $gt: '>'
  $gte: '>='

_appendWhere = (query, find, cursor) ->
  for key, value of find
    continue if _.isUndefined(value)
    if value.$in
      if value.$in?.length then query.whereIn(key, value.$in) else (query.abort = true; return query)
    else if value.$lt or value.$lte or value.$gt or value.$gte
      # Transform a conditional of type {key: {$lt: 5}} to ('key', '<', 5)
      (condition = COMPARATORS[comparator]; parameter = value[comparator]) for comparator in _.keys(COMPARATORS) when value[comparator]
      query.where(key, condition, parameter)
    else
      query.where(key, value)
  if cursor.$ids
    (query.abort = true; return query) unless cursor.$ids.length
    query.whereIn(id, cursor.$ids)
  return query

_appendSort = (query, sorts) ->
  sorts = if _.isArray(sorts) then sorts else [sorts]
  for sort in sorts
    if sort[0] is '-'
      dir = 'desc'
      col = sort.substr(1)
    else
      dir = 'asc'
      col = sort
    query.orderBy(col, dir)
  return query

module.exports = class SqlCursor extends Cursor

  toJSON: (callback, count) ->
    schema = @model_type.schema()

    query = _appendWhere(@connection(@model_type._table), @_find, @_cursor)

    # $in : [] or another invalid clause has been given
    return callback(null, if @_cursor.$count then 0 else if @_cursor.$one then null else []) if query.abort

    if count or @_cursor.$count
      return query.count('*').exec (err, json) => callback(null, if json.length then json[0].aggregate else 0)

    # only select specific fields
    if @_cursor.$values
      $fields = if @_cursor.$white_list then _.intersection(@_cursor.$values, @_cursor.$white_list) else @_cursor.$values
    else if @_cursor.$select
      $fields = if @_cursor.$white_list then _.intersection(@_cursor.$select, @_cursor.$white_list) else @_cursor.$select
    else if @_cursor.$white_list
      $fields = @_cursor.$white_list

    if @_cursor.$include
      @include_keys = if _.isArray(@_cursor.$include) then @_cursor.$include else [@_cursor.$include]

      from_columns = if $fields then _.clone($fields) else schema.allColumns()
      from_columns.push('id') unless 'id' in from_columns
      from_columns = ("#{@model_type._table}.#{col} as #{@tablePrefix(@model_type)}#{col}" for col in from_columns)
      to_columns = []

      for key in @include_keys
        relation = @model_type.relation(key)
        related_model = relation.reverse_relation.model_type

        if relation.type is 'belongsTo'
          from_key = "#{@model_type._table}.#{relation.foreign_key}"
          to_key = "#{related_model._table}.id"
        else
          from_key = "#{@model_type._table}.id"
          to_key = "#{related_model._table}.#{relation.foreign_key}"

        building_columns = relation.reverse_relation.model_type.schema().allColumns()
        building_columns.push('id') unless 'id' in from_columns
        to_columns = to_columns.concat("#{related_model._table}.#{col} as #{@tablePrefix(related_model)}#{col}" for col in building_columns)

        query.join(related_model._table, from_key, '=', to_key)

      query.select(from_columns.concat(to_columns))

    else
      query.select($fields if $fields)
      query.limit(1) if @_cursor.$one
      query.limit(@_cursor.$limit) if @_cursor.$limit
      query.offset(@_cursor.$offset) if @_cursor.$offset

    _appendSort(query, @_cursor.$sort) if @_cursor.$sort

    return query.exec (err, json) =>

      if @_cursor.$include
        json = @parseInclude(json)

      return callback(null, if json.length then @backbone_adapter.nativeToAttributes(json[0], schema) else null) if @_cursor.$one
      @backbone_adapter.nativeToAttributes(model_json, schema) for model_json in json

      if @_cursor.$values
        $values = if @_cursor.$white_list then _.intersection(@_cursor.$values, @_cursor.$white_list) else @_cursor.$values
        if @_cursor.$values.length is 1
          key = @_cursor.$values[0]
          json = if $values.length then ((if item.hasOwnProperty(key) then item[key] else null) for item in json) else _.map(json, -> null)
        else
          json = (((item[key] for key in $values when item.hasOwnProperty(key))) for item in json)
      else if @_cursor.$select
        $select = if @_cursor.$white_list then _.intersection(@_cursor.$select, @_cursor.$white_list) else @_cursor.$select
        json = _.map(json, (item) => _.pick(item, $select))
      else if @_cursor.$white_list
        json = _.map(json, (item) => _.pick(item, @_cursor.$white_list))

      if @_cursor.$page or @_cursor.$page is ''
        _appendWhere(@connection(@model_type._table), @_find, @_cursor).count('*').exec (err, count_json) =>
          json =
            offset: @_cursor.$offset
            total_rows: if count_json.length then count_json[0].aggregate else 0
            rows: json
          callback(null, json)
      else
        callback(null, json)

  tablePrefix: (model_type) -> "_#{model_type._table}_"

  # Rows returned from a join query need to be un-merged into the correct json format
  parseInclude: (raw_json) ->
    json = []

    for key in @include_keys
      relation = @model_type.relation(key)
      related_model = relation.reverse_relation.model_type

      for row in raw_json
        model_json = {}
        related_json = {}

        # Fields are prefixed with the table name of the model they belong to so we can test which the values are for
        for key, value of row
          if match = new RegExp("^#{@tablePrefix(@model_type)}(.*)$").exec(key)
            model_json[match[1]] = value
          else if match = new RegExp("^#{@tablePrefix(related_model)}(.*)$").exec(key)
            related_json[match[1]] = value

        # If there was a hasMany relationship or multiple $includes we'll have multiple rows for each model
        if found = _.find(json, (test) -> test.id is model_json.id)
          model_json = found
        # Add this model to the result if we haven't already
        else
          json.push(model_json)

        if relation.type is 'hasMany'
          model_json[relation.key] or= []
          model_json[relation.key].push(related_json)
        else
          model_json[relation.key] = related_json

    return json
