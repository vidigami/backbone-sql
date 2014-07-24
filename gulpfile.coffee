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

gulp.task 'watch', ['build'], (callback) ->
  return gulp.watch './src/**/*.coffee', -> buildLibraries()

MOCHA_DATABASE_OPTIONS =
  postgres: {require: ['test/parameters_postgres', 'backbone-rest/test/parameters_express4'], env: {NODE_ENV: 'test'}}
  mysql: {require: ['test/parameters_mysql', 'backbone-rest/test/parameters_express4'], env: {NODE_ENV: 'test'}}
  sqlite3: {require: ['test/parameters_sqlite3', 'backbone-rest/test/parameters_express4'], env: {NODE_ENV: 'test'}}

testFn = (options={}) -> (callback) ->
  gutil.log "Running tests for #{options.protocol} #{if options.quick then '(quick)' else ''}"
  mocha_options = _.extend((if options.quick then {grep: '@no_options'} else {}), MOCHA_DATABASE_OPTIONS[options.protocol])
  return gulp.src("{node_modules/backbone-#{if options.quick then 'orm' else '{orm,rest}'}/,}test/{issues,spec/sync,spec/node}/**/*.tests.coffee")
    .pipe(mocha(mocha_options))
    .pipe es.writeArray callback

gulp.task 'test', ['build'], (callback) ->
  Async.series (testFn({protocol: protocol}) for protocol of MOCHA_DATABASE_OPTIONS), callback
  return # promises workaround: https://github.com/gulpjs/gulp/issues/455
gulp.task 'test-postgres', ['build'], testFn({protocol: 'postgres'})
gulp.task 'test-mysql', ['build'], testFn({protocol: 'mysql'})
gulp.task 'test-sqlite3', ['build'], testFn({protocol: 'sqlite3'})
gulp.task 'test-quick', [], testFn({quick: true, protocol: 'postgres'})
gulp.task 'test-quick-all', ['build'], (callback) ->
  Async.series (testFn({quick: true, protocol: protocol}) for protocol of MOCHA_DATABASE_OPTIONS), callback
  return # promises workaround: https://github.com/gulpjs/gulp/issues/455

# gulp.task 'benchmark', ['build'], (callback) ->
#   (require './test/lib/run_benchmarks')(callback)
#   return # promises workaround: https://github.com/gulpjs/gulp/issues/455
