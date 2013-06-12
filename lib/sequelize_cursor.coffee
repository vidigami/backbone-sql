util = require 'util'
_ = require 'underscore'

Cursor = require 'backbone-node/lib/cursor'

_sortArgsToSequelize = (args) ->
  args = if Array.isArray(args) then args else [args]
  return ((if arg.charAt(0) is '-' then arg.substr(1) + ' DESC' else arg) for arg in args)

module.exports = class SequelizeCursor extends Cursor
  ##############################################
  # Execution of the Query
  ##############################################
  toJSON: (callback, count) ->
    find = {where: @backbone_adapter.attributesToNative(@_find)}
    find.order = _sortArgsToSequelize(@_cursor.$sort) if @_cursor.$sort
    find.offset = @_cursor.$offset if @_cursor.$offset
    if @_cursor.$one
      find.limit = 1
    else if @_cursor.$limit
      find.limit = @_cursor.$limit
    # args._id = {$in: _.map(ids, (id) -> new ObjectID("#{id}"))} if @_cursor.$ids # TODO
    args = [find]

    return @connection.count(find).error(callback).success((count) -> callback(null, count)) if count or @_cursor.$count # only the count

    # only select specific fields
    if @_cursor.$values
      $fields = if @_cursor.$white_list then _.intersection(@_cursor.$values, @_cursor.$white_list) else @_cursor.$values
    else if @_cursor.$select
      $fields = if @_cursor.$white_list then _.intersection(@_cursor.$select, @_cursor.$white_list) else @_cursor.$select
    else if @_cursor.$white_list
      $fields = @_cursor.$white_list
    args.push({attributes: $fields}) if $fields
    # args.push({raw: true}) # can't use raw or else booleans aren't mapped correctly, eg. false -> 0

    # call
    @connection.findAll.apply(@connection, args)
      .error(callback)
      .success (seq_models) =>
        return callback(null, if seq_models.length then @backbone_adapter.nativeToAttributes(seq_models[0]) else null) if @_cursor.$one
        json = _.map(seq_models, (seq_model) => @backbone_adapter.nativeToAttributes(seq_model))

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

        if @_cursor.hasOwnProperty('$page')
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
