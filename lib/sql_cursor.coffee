util = require 'util'
_ = require 'underscore'
Knex = require 'knex'

Cursor = require 'backbone-orm/lib/cursor'

COMPARATORS =
  $lt: '<'
  $lte: '<='
  $gt: '>'
  $gte: '>='
  $ne: '!='

_appendCondition = (conditions, key, value) ->
  if value?.$in
    if value.$in?.length then conditions.where_ins.push({key: key, value: value.$in}) else (conditions.abort = true; return conditions)

  # Transform a conditional of type {key: {$lt: 5}} to ('key', '<', 5)
  else if mongo_op = _.find(_.keys(COMPARATORS), (test) -> value.hasOwnProperty(test))
    parameter = value[mongo_op]
    operator = COMPARATORS[mongo_op]
    conditions.where_conditionals.push({key: key, operator: operator, value: parameter})

  else
    conditions.wheres.push({key: key, value: value})
  return conditions

_parseConditions = (find, cursor) ->
  conditions = {wheres: [], where_conditionals: [], where_ins: [], related_wheres: {}}
  related_wheres = {}
  for key, value of find
    continue if _.isUndefined(value)

    # A dot indicates a condition on a related model
    if key.indexOf('.') > 0
      [relation, key] = key.split('.')
      related_wheres[relation] or= {}
      related_wheres[relation][key] = value
    else
      _appendCondition(conditions, key, value)

  # Parse conditions on related models in the same way
  conditions.related_wheres[relation] = _parseConditions(related_conditions) for relation, related_conditions of related_wheres

  if cursor?.$ids
    (conditions.abort = true; return conditions) unless cursor.$ids.length
    conditions.where_ins.push({key: id, value: cursor.$ids})

  return conditions

_columnName = (col, table) -> if table then "#{table}.#{col}" else col

_appendWhere = (query, conditions, table) ->
  for condition in conditions.wheres
    query.where(_columnName(condition.key, table), condition.value)
  for condition in conditions.where_conditionals
    query.where(_columnName(condition.key, table), condition.operator, condition.value)
  for condition in conditions.where_ins
    query.whereIn(_columnName(condition.key, table), condition.value)
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

    query = @connection(@model_type._table)
    conditions = _parseConditions(@_find, @_cursor)

    # $in : [] or another query that would result in an empty result set in mongo has been given
    return callback(null, if @_cursor.$count then 0 else if @_cursor.$one then null else []) if conditions.abort

    _appendWhere(query, conditions)

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
      throw Error("Invalid include specified: #{@include_keys}") unless @include_keys.length

      # Join the related tables
      @joined = true
      to_columns = []
      for key in @include_keys
        relation = @_getRelation(key)
        related_model = relation.reverse_relation.model_type

        # Compile the columns for the related model and prefix them with its table name
        to_columns = to_columns.concat(@_prefixColumns(related_model))

        @_joinTo(query, relation)

        # Use the full table name when adding the where clauses
        if related_wheres = conditions.related_wheres[key]
          _appendWhere(query, related_wheres, related_model._table)

      # Compile the columns for this model and prefix them with its table name
      from_columns = @_prefixColumns(@model_type, $fields)
      query.select(from_columns.concat(to_columns))

    else
      #todo: do these make sense with joins? apply them after un-joining the result?
      query.limit(1) if @_cursor.$one
      query.limit(@_cursor.$limit) if @_cursor.$limit
      query.offset(@_cursor.$offset) if @_cursor.$offset
      # Apply the field selection if present and there's no joins required
      query.select($fields if $fields) if _.isEmpty(conditions.related_wheres)

    unless _.isEmpty(conditions.related_wheres)
      # Skip any relations we've processed with $include
      if @include_keys
        conditions.related_wheres = _.omit(conditions.related_wheres, @include_keys)
      else
        @joined = true
        query.select((@_prefixColumns(@model_type, $fields)))

      # Join the related table and add the related where conditions, using the full table name, for each related query
      for key, related_wheres of conditions.related_wheres
        relation = @_getRelation(key)
        @_joinTo(query, relation)
        _appendWhere(query, related_wheres, relation.reverse_relation.model_type._table)

    _appendSort(query, @_cursor.$sort) if @_cursor.$sort

    if @verbose
      console.log '\n----------'
      console.log query.toString()
      console.log '----------'
    return query.exec (err, json) =>
      return callback(err, if @_cursor.$count then 0 else if @_cursor.$one then null else []) if err

      json = @_joinedResultsToJSON(json) if @joined

      return callback(null, if json.length then @backbone_adapter.nativeToAttributes(json[0], schema) else null) if @_cursor.$one
      @backbone_adapter.nativeToAttributes(model_json, schema) for model_json in json

      if @_cursor.$values
        $values = if @_cursor.$white_list then _.intersection(@_cursor.$values, @_cursor.$white_list) else @_cursor.$values
        if @_cursor.$values.length is 1
          key = @_cursor.$values[0]
          json = if $values.length then ((if item.hasOwnProperty(key) then item[key] else null) for item in json) else _.map(json, -> null)
        else
          json = (((item[key] for key in $values when item.hasOwnProperty(key))) for item in json)
      # These are checked again in case we appended id to the field list, which was necessary for joins
      else if @_cursor.$select
        $select = if @_cursor.$white_list then _.intersection(@_cursor.$select, @_cursor.$white_list) else @_cursor.$select
        json = _.map(json, (item) => _.pick(item, $select))
      else if @_cursor.$white_list
        json = _.map(json, (item) => _.pick(item, @_cursor.$white_list))

      if @_cursor.$page or @_cursor.$page is ''
        _appendWhere(@connection(@model_type._table), conditions).count('*').exec (err, count_json) =>
          json =
            offset: @_cursor.$offset
            total_rows: if count_json.length then count_json[0].aggregate else 0
            rows: json
          callback(null, json)
      else
        callback(null, json)

  _joinTo: (query, relation) ->
    related_model = relation.reverse_relation.model_type
    if relation.type is 'hasMany' and relation.reverse_relation.type is 'hasMany'
      pivot_table = relation.join_table._table

      # Join the from model to the pivot table
      from_key = "#{@model_type._table}.id"
      pivot_to_key = "#{pivot_table}.#{relation.foreign_key}"
      query.join(pivot_table, from_key, '=', pivot_to_key)

      # Then to the to model's table
      pivot_from_key = "#{pivot_table}.#{relation.reverse_relation.foreign_key}"
      to_key = "#{related_model._table}.id"
      query.join(related_model._table, pivot_from_key, '=', to_key)
    else
      if relation.type is 'belongsTo'
        from_key = "#{@model_type._table}.#{relation.foreign_key}"
        to_key = "#{related_model._table}.id"
      else
        from_key = "#{@model_type._table}.id"
        to_key = "#{related_model._table}.#{relation.foreign_key}"
      query.join(related_model._table, from_key, '=', to_key)

  # Rows returned from a join query need to be un-merged into the correct json format
  _joinedResultsToJSON: (raw_json) ->
    return raw_json unless raw_json and raw_json.length

    json = []
    for row in raw_json
      model_json = {}
      row_relation_json = {}

      # Fields are prefixed with the table name of the model they belong to so we can test which the values are for
      # and assign them to the correct object
      for key, value of row
        if match = @_prefixRegex(@model_type).exec(key)
          model_json[match[1]] = value
        else if @include_keys
          for include_key in @include_keys
            related_json = (row_relation_json[include_key] or= {})
            related_model = @model_type.relation(include_key).reverse_relation.model_type
            if match = @_prefixRegex(related_model).exec(key)
              related_json[match[1]] = value

      # If there was a hasMany relationship or multiple $includes we'll have multiple rows for each model
      if found = _.find(json, (test) -> test.id is model_json.id)
        model_json = found
      # Add this model to the result if we haven't already
      else
        json.push(model_json)

      # Add relations to the model_json if included
      for include_key, related_json of row_relation_json
        unless _.isEmpty(related_json)
          if @model_type.relation(include_key).type is 'hasMany'
            model_json[include_key] or= []
            model_json[include_key].push(related_json) unless _.find(model_json[include_key], (test) -> test.id is related_json.id)
          else
            model_json[include_key] = related_json

    return json

  _prefixColumns: (model_type, fields) ->
    columns = if fields then _.clone(fields) else model_type.schema().allColumns()
    columns.push('id') unless 'id' in columns
    return ("#{model_type._table}.#{col} as #{@_tablePrefix(model_type)}#{col}" for col in columns)

  _tablePrefix: (model_type) -> "#{model_type._table}_"

  _prefixRegex: (model_type) -> new RegExp("^#{@_tablePrefix(model_type)}(.*)$")

  _getRelation: (key) ->
    throw new Error("#{key} is not a relation of #{@model_type.model_name}") unless relation = @model_type.relation(key)
    return relation