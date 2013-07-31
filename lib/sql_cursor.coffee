util = require 'util'
_ = require 'underscore'
Knex = require 'knex'

Cursor = require 'backbone-orm/lib/cursor'

COMPARATORS =
  $lt: '<'
  $lte: '<='
  $gt: '>'
  $gte: '>='

# Transform a conditional of type {key: {$lt: 5}} to {condition: '<', value: 5}
_knexConditional = (comparator, key, value) ->
  return {condition: COMPARATORS[comparator], value: value[comparator]}

_appendWhere = (query, find, cursor) ->
  for key, value of find
    continue if _.isUndefined(value)
    if value.$in
      if value.$in?.length then query.whereIn(key, value.$in) else (query.abort = true; return query)
    else if value.$lt or value.$lte or value.$gt or value.$gte
      (condition = COMPARATORS[comparator]; parameter = value[comparator]) for comparator in _.keys(COMPARATORS) when value[comparator]
      query.where(key, condition, parameter)
    else
      query.where(key, value)
  query.whereIn(id, cursor.$ids) if cursor.$ids
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

    if @_cursor.$include
      console.log 'todo: include'
#      $include_keys = if _.isArray(@_cursor.$include) then @_cursor.$include else [@_cursor.$include]
#      find.include = (@model_type.relation(key).reverse_model_type._connection for key in $include_keys)
#      many_relateds = _.some(@model_type._relations, (r) -> r.type is 'hasMany')

    # only select specific fields
    if @_cursor.$values
      $fields = if @_cursor.$white_list then _.intersection(@_cursor.$values, @_cursor.$white_list) else @_cursor.$values
    else if @_cursor.$select
      $fields = if @_cursor.$white_list then _.intersection(@_cursor.$select, @_cursor.$white_list) else @_cursor.$select
    else if @_cursor.$white_list
      $fields = @_cursor.$white_list

    query.select($fields if $fields)
    query.limit(1) if @_cursor.$one
    query.limit(@_cursor.$limit) if @_cursor.$limit
    query.offset(@_cursor.$offset) if @_cursor.$offset
    _appendSort(query, @_cursor.$sort) if @_cursor.$sort

    return query.exec (err, json) =>
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
