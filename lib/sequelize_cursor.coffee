util = require 'util'
_ = require 'underscore'

Cursor = require 'backbone-orm/lib/cursor'

_sortArgsToSequelize = (args) ->
  args = if _.isArray(args) then args else [args]
  return ((if arg[0] is '-' then arg.substr(1) + ' DESC' else arg) for arg in args)

module.exports = class SequelizeCursor extends Cursor
  ##############################################
  # Execution of the Query
  ##############################################
  toJSON: (callback, count) ->
    schema = @model_type.schema()
    find = {where: @backbone_adapter.attributesToNative(@_find, schema)}
    find.order = _sortArgsToSequelize(@_cursor.$sort) if @_cursor.$sort
    find.offset = @_cursor.$offset if @_cursor.$offset
    if @_cursor.$one
      find.limit = 1
    else if @_cursor.$limit
      find.limit = @_cursor.$limit

    # $in to sequelize format ( field: [list, of, values] )
    (find.where[key] = value.$in) for key, value of find.where when value?.$in
    find.where.id = @_cursor.$ids if @_cursor.$ids
    args = [find]

    return @connection.count(find).error(callback).success((count) -> callback(null, count)) if count or @_cursor.$count # only the count

    if @_cursor.$include
      $include_keys = if _.isArray(@_cursor.$include) then @_cursor.$include else [@_cursor.$include]
      find.include = (@model_type.relation(key).reverse_model_type._sync.connection for key in $include_keys)
      many_relateds = _.some(@model_type._sync.relations, (r) -> r.type is 'hasMany')


    # only select specific fields
    if @_cursor.$values
      $fields = if @_cursor.$white_list then _.intersection(@_cursor.$values, @_cursor.$white_list) else @_cursor.$values
    else if @_cursor.$select
      $fields = if @_cursor.$white_list then _.intersection(@_cursor.$select, @_cursor.$white_list) else @_cursor.$select
    else if @_cursor.$white_list
      $fields = @_cursor.$white_list
    args.push({attributes: $fields}) if $fields
    args.push({raw: true})

    # call
    @connection.findAll.apply(@connection, args)
      .error(callback)
      .success (json) =>
        if many_relateds
          json = unJoinJSON(json)
        return callback(null, if json.length then @backbone_adapter.nativeToAttributes(json[0], schema) else null) if @_cursor.$one
        @backbone_adapter.nativeToAttributes(model_json, schema) for model_json in json

        # TODO: OPTIMIZE TO REMOVE 'id' and '_rev' if needed
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
          # sequelize doesn't like limit / offset in count queries
          @connection.count({ where: find.where }).error(callback).success (count) =>
            json =
              offset: @_cursor.$offset
              total_rows: count
              rows: json
            callback(null, json)
        else
          callback(null, json)
    return # terminating

  #todo: separate the joined data back in to proper json
  unJoinJSON: (json) ->
    return json