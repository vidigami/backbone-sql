###
  backbone-sql.js 0.5.10
  Copyright (c) 2013 Vidigami - https://github.com/vidigami/backbone-sql
  License: MIT (http://www.opensource.org/licenses/mit-license.php)
###

util = require 'util'
_ = require 'underscore'
Knex = require 'knex'

{Cursor} = (require 'backbone-orm').sync

COMPARATORS =
  $lt: '<'
  $lte: '<='
  $gt: '>'
  $gte: '>='
  $ne: '!='
COMPARATOR_KEYS = _.keys(COMPARATORS)

_appendCondition = (conditions, key, value) ->

  if value?.$in
    if value.$in?.length then conditions.where_ins.push({key: key, value: value.$in}) else (conditions.abort = true; return conditions)

  else if value?.$nin
    if value.$nin?.length then conditions.where_nins.push({key: key, value: value.$nin})

  # Transform a conditional of type {key: {$lt: 5}} to ('key', '<', 5)
  else if _.isObject(value) and ops_length = _.size(mongo_ops = _.pick(value, COMPARATOR_KEYS))
    operations = []
    for mongo_op, parameter of mongo_ops
      # TODO: should return an error for null on an operator unless it is $ne, but there is no callback
      throw new Error "Unexpected null with query key '#{key}' operator '#{operator}'" if _.isNull(value) and (operator isnt '$ne')
      operations.push({operator: COMPARATORS[mongo_op], value: parameter})
    if ops_length is 1
      conditions.where_conditionals.push(_.extend(operations[0], {key: key}))
    else
      conditions.where_conditionals.push({key: key, operations: operations})

  else
    conditions.wheres.push({key: key, value: value})
  return conditions

_columnName = (col, table) -> if table then "#{table}.#{col}" else col

_appendConditionalWhere = (query, key, condition, table, compound) ->
  whereMethod = if compound then 'andWhere' else 'where'
  if condition.operator is '!='
    # != should function like $ne, including nulls
    query[whereMethod] ->
      if _.isNull(condition.value)
        @whereNotNull(_columnName(key, table))
      else
        @where(_columnName(key, table), condition.operator, condition.value).orWhereNull(_columnName(key, table))
  else
    query[whereMethod](_columnName(key, table), condition.operator, condition.value)

_appendWhere = (query, conditions, table) ->
  for condition in conditions.wheres
    if _.isNull(condition.value)
      query.whereNull(_columnName(condition.key, table))
    else
      query.where(_columnName(condition.key, table), condition.value)

  for condition in conditions.where_conditionals
    if condition.operations
      query.where ->
        operation = condition.operations.pop()
        nested_query = @
        _appendConditionalWhere(nested_query, condition.key, operation, table, false)
        for operation in condition.operations
          _appendConditionalWhere(nested_query, condition.key, operation, table, true)
    else if _.isNull(condition.value)
      query.whereNotNull(_columnName(condition.key, table))
    else
      _appendConditionalWhere(query, condition.key, condition, table, false)

  for condition in conditions.where_ins
    query.whereIn(_columnName(condition.key, table), condition.value)

  for condition in conditions.where_nins
    query.whereNotIn(_columnName(condition.key, table), condition.value)

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

_extractCount = (count_json) ->
  return 0 unless count_json?.length
  count_info = count_json[0]
  return +(count_info[if count_info.hasOwnProperty('count(*)') then 'count(*)' else 'count'])

module.exports = class SqlCursor extends Cursor

  _parseConditions: (find, cursor) ->
    conditions = {wheres: [], where_conditionals: [], where_ins: [], where_nins: [], related_wheres: {}, joined_wheres: {}}
    related_wheres = {}
    for key, value of find
      throw new Error "Unexpected undefined for query key '#{key}'" if _.isUndefined(value)

      # A dot indicates a condition on a related model
      if key.indexOf('.') > 0
        [relation, key] = key.split('.')
        related_wheres[relation] or= {}
        related_wheres[relation][key] = value

      # Many to Many relationships may be queried on the foreign key of the join table
      else if (reverse_relation = @model_type.reverseRelation(key)) and reverse_relation.join_table
        relation = reverse_relation.reverse_relation
        conditions.joined_wheres[relation.key] or= {wheres: [], where_conditionals: [], where_ins: [], where_nins: []}
        _appendCondition(conditions.joined_wheres[relation.key], key, value)
      else
        _appendCondition(conditions, key, value)

    # Parse conditions on related models in the same way
    conditions.related_wheres[relation] = @_parseConditions(related_conditions) for relation, related_conditions of related_wheres

    if cursor?.$ids
      (conditions.abort = true; return conditions) unless cursor.$ids.length
      conditions.where_ins.push({key: 'id', value: cursor.$ids})

    return conditions

  queryToJSON: (callback) ->
    return callback(null, if @hasCursorQuery('$one') then null else []) if @hasCursorQuery('$zero')

    try
      query = @connection(@model_type.tableName())
      @_conditions = @_parseConditions(@_find, @_cursor)

      # $in : [] or another query that would result in an empty result set in mongo has been given
      return callback(null, if @_cursor.$count then 0 else (if @_cursor.$one then null else [])) if @_conditions.abort

      _appendWhere(query, @_conditions, @model_type.tableName())
    catch err
      return callback("Query failed for model: #{@model_type.model_name} with error: #{err}")

    # count and exists when there is not a join table
    if @hasCursorQuery('$count') or @hasCursorQuery('$exists')
      @_appendRelatedWheres(query)
      @_appendJoinedWheres(query)
      if @hasCursorQuery('$count')
        return query.count('*').exec (err, count_json) => callback(null, _extractCount(count_json))
      else
        return query.count('*').limit(1).exec (err, count_json) => callback(null, _extractCount(count_json) > 0)

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
        related_model_type = relation.reverse_relation.model_type

        # Compile the columns for the related model and prefix them with its table name
        to_columns = to_columns.concat(@_prefixColumns(related_model_type))

        @_joinTo(query, relation)

        # Use the full table name when adding the where clauses
        if related_wheres = @_conditions.related_wheres[key]
          (@queued_queries or= []).push(key)
          _appendWhere(query, related_wheres, related_model_type.tableName())

      # Compile the columns for this model and prefix them with its table name
      from_columns = @_prefixColumns(@model_type, $fields)
      $columns = from_columns.concat(to_columns)

    else
      # TODO: do these make sense with joins? apply them after un-joining the result?
      query.limit(1) if @_cursor.$one
      query.limit(@_cursor.$limit) if @_cursor.$limit
      query.offset(@_cursor.$offset) if @_cursor.$offset

    # Append where conditions and join if needed for the form `related_model.field = value`
    @_appendRelatedWheres(query)

    # Append where conditions and join if needed for the form `manytomanyrelation_id.field = value`
    @_appendJoinedWheres(query)

    $columns or= if @joined then @_prefixColumns(@model_type, $fields) else $fields
    query.select($columns)
    _appendSort(query, @_cursor.$sort) if @_cursor.$sort

    if @verbose
    # if true
      console.log '\n----------'
      console.log query.toString()
      console.log '----------'

    return query.exec (err, json) =>
      return callback(new Error("Query failed for model: #{@model_type.model_name} with error: #{err}")) if err
      json = @_joinedResultsToJSON(json) if @joined

      if @queued_queries
        @_appendCompleteRelations(json, callback)
      else
        @_processResponse(json, callback)

  # Process any remaining queries and return the json
  _processResponse: (json, callback) ->
    schema = @model_type.schema()

    @backbone_adapter.nativeToAttributes(model_json, schema) for model_json in json
    json = @selectResults(json)

    # NOTE: limit and offset would apply to the join table so do as post-process. TODO: optimize
    if @_cursor.$include
      if @_cursor.$offset
        number = json.length - @_cursor.$offset
        number = 0 if number < 0
        json = if number then json.slice(@_cursor.$offset, @_cursor.$offset+number) else []

      if @_cursor.$limit
        json = json.splice(0, Math.min(json.length, @_cursor.$limit))

    if @hasCursorQuery('$page')
      query = @connection(@model_type.tableName())
      _appendWhere(query, @_conditions)
      @_appendRelatedWheres(query)
      @_appendJoinedWheres(query)
      query.count('*').exec (err, count_json) =>
        return callback(err) if err
        callback(null, {
          offset: @_cursor.$offset or 0
          total_rows: _extractCount(count_json)
          rows: json
        })
    else
      callback(null, json)

  # Make another query to get the complete set of related objects when they have been fitered by a where clause
  _appendCompleteRelations: (json, callback) ->
    new_query = @connection(@model_type.tableName())
    new_query.whereIn(_columnName('id', @model_type.tableName()), _.pluck(json, 'id'))
    to_columns = []
    for key in @queued_queries
      relation = @_getRelation(key)
      related_model_type = relation.reverse_relation.model_type
      to_columns = to_columns.concat(@_prefixColumns(related_model_type))
      @_joinTo(new_query, relation)

    new_query.select((@_prefixColumns(@model_type, ['id'])).concat(to_columns))
    new_query.exec (err, new_json) =>
      relation_json = @_joinedResultsToJSON(new_json)
      for placeholder in relation_json
        model = _.find(json, (test) -> test.id is placeholder.id)
        _.extend(model, placeholder)
      @_processResponse(json, callback)

  _appendRelatedWheres: (query) ->
    return if _.isEmpty(@_conditions.related_wheres)

    @joined = true
    # Skip any relations we've processed with $include
    if @include_keys
      @_conditions.related_wheres = _.omit(@_conditions.related_wheres, @include_keys)

    # Join the related table and add the related where conditions, using the full table name, for each related query
    for key, related_wheres of @_conditions.related_wheres
      relation = @_getRelation(key)
      @_joinTo(query, relation)
      _appendWhere(query, related_wheres, relation.reverse_relation.model_type.tableName())

  _appendJoinedWheres: (query) ->
    return if _.isEmpty(@_conditions.joined_wheres)

    @joined = true
    # Ensure that a join with the join table occurs and add the where clause for the foreign key
    for key, joined_wheres of @_conditions.joined_wheres
      relation = @_getRelation(key)
      unless key in _.keys(@_conditions.related_wheres) or (@include_keys and key in @include_keys)
        from_key = "#{@model_type.tableName()}.id"
        to_key = "#{relation.join_table.tableName()}.#{relation.foreign_key}"
        query.join(relation.join_table.tableName(), from_key, '=', to_key, 'left outer')
      _appendWhere(query, joined_wheres, relation.join_table.tableName())

  # TODO: look at optimizing without left outer joins everywhere
  # Make another query to get the complete set of related objects when they have been fitered by a where clause
  _joinTo: (query, relation) ->
    related_model_type = relation.reverse_relation.model_type
    if relation.type is 'hasMany' and relation.reverse_relation.type is 'hasMany'
      pivot_table = relation.join_table.tableName()

      # Join the from model to the pivot table
      from_key = "#{@model_type.tableName()}.id"
      pivot_to_key = "#{pivot_table}.#{relation.foreign_key}"
      query.join(pivot_table, from_key, '=', pivot_to_key, 'left outer')

      # Then to the to model's table
      pivot_from_key = "#{pivot_table}.#{relation.reverse_relation.foreign_key}"
      to_key = "#{related_model_type.tableName()}.id"
      query.join(related_model_type.tableName(), pivot_from_key, '=', to_key, 'left outer')
    else
      if relation.type is 'belongsTo'
        from_key = "#{@model_type.tableName()}.#{relation.foreign_key}"
        to_key = "#{related_model_type.tableName()}.id"
      else
        from_key = "#{@model_type.tableName()}.id"
        to_key = "#{related_model_type.tableName()}.#{relation.foreign_key}"
      query.join(related_model_type.tableName(), from_key, '=', to_key, 'left outer')

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
            related_model_type = @model_type.relation(include_key).reverse_relation.model_type
            if match = @_prefixRegex(related_model_type).exec(key)
              related_json[match[1]] = value

      # If there was a hasMany relationship or multiple $includes we'll have multiple rows for each model
      if found = _.find(json, (test) -> test.id is model_json.id)
        model_json = found
      # Add this model to the result if we haven't already
      else
        json.push(model_json)

      # Add relations to the model_json if included
      for include_key, related_json of row_relation_json
        if _.isNull(related_json.id)
          if @model_type.relation(include_key).type is 'hasMany'
            model_json[include_key] = []
          else
            model_json[include_key] = null
        else if not _.isEmpty(related_json)
          reverse_relation_schema = @model_type.relation(include_key).reverse_relation.model_type.schema()
          related_json = @backbone_adapter.nativeToAttributes(related_json, reverse_relation_schema)
          if @model_type.relation(include_key).type is 'hasMany'
            model_json[include_key] or= []
            model_json[include_key].push(related_json) unless _.find(model_json[include_key], (test) -> test.id is related_json.id)
          else
            model_json[include_key] = related_json

    return json

  _prefixColumns: (model_type, fields) ->
    columns = if fields then _.clone(fields) else model_type.schema().columns()
    columns.push('id') unless 'id' in columns
    return ("#{model_type.tableName()}.#{col} as #{@_tablePrefix(model_type)}#{col}" for col in columns)

  _tablePrefix: (model_type) -> "#{model_type.tableName()}_"

  _prefixRegex: (model_type) -> new RegExp("^#{@_tablePrefix(model_type)}(.*)$")

  _getRelation: (key) ->
    throw new Error("#{key} is not a relation of #{@model_type.model_name}") unless relation = @model_type.relation(key)
    return relation
