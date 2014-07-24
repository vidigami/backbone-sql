_ = require 'underscore'
es = require 'event-stream'

Async = require 'async'
gulp = require 'gulp'
gutil = require 'gulp-util'
coffee = require 'gulp-coffee'
mocha = require 'gulp-spawn-mocha'

gulp.task 'build', buildLibraries = ->
  return gulp.src('./src/**/*.coffee')
    .pipe(coffee({header: true})).on('error', gutil.log)
    .pipe(gulp.dest('./lib'))
  # return stream instead of explicit callback https://github.com/gulpjs/gulp/blob/master/docs/API.md

gulp.task 'watch', ['build'], (callback) ->
  return gulp.watch './src/**/*.coffee', -> buildLibraries()

mocha_db_options =
  postgres: {require: ['test/parameters_postgres', 'backbone-rest/test/parameters_express4'], env: {NODE_ENV: 'test'}}
  mysql: {require: ['test/parameters_mysql', 'backbone-rest/test/parameters_express4'], env: {NODE_ENV: 'test'}}
  sqlite3: {require: ['test/parameters_sqlite3', 'backbone-rest/test/parameters_express4'], env: {NODE_ENV: 'test'}}

testFn = (options={}) -> (callback) ->
  gutil.log "Running tests for #{options.db} #{if options.quick then '(quick)' else ''}"
  mocha_options = _.extend((if options.quick then {grep: '@no_options'} else {}), mocha_db_options[options.db])
  gulp.src("{node_modules/backbone-#{if options.quick then 'orm' else '{orm,rest}'}/,}test/{issues,spec}/**/*.tests.coffee")
    .pipe(mocha(mocha_options))
    .pipe es.writeArray callback
  return # promises workaround: https://github.com/gulpjs/gulp/issues/455

gulp.task 'test', ['build'], (callback) ->
  Async.series (testFn({db: db_name}) for db_name of mocha_db_options), callback
  return
gulp.task 'test-postgres', ['build'], testFn({db: 'postgres'})
gulp.task 'test-mysql', ['build'], testFn({db: 'mysql'})
gulp.task 'test-sqlite3', ['build'], testFn({db: 'sqlite3'})
gulp.task 'test-quick', [], testFn({quick: true, db: 'postgres'})
gulp.task 'test-quick-all', ['build'], (callback) ->
  Async.series (testFn({quick: true, db: db_name}) for db_name of mocha_db_options), callback
  return

# gulp.task 'benchmark', ['build'], (callback) ->
#   (require './test/lib/run_benchmarks')(callback)
#   return # promises workaround: https://github.com/gulpjs/gulp/issues/455
